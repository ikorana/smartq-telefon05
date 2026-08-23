import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:telefon05/theme/app_colors.dart';
import 'base.dart';
import 'device_card_base.dart';
import 'ins_ui_helper.dart';
import 'ins_anahtar.dart';
import 'ins_hareket.dart';
import 'ins_temp.dart';
import 'tool.dart';
import '../user/userManagementService.dart';
import '../user/appUser.dart';
import '../comminication/comminication.dart' hide DeviceType;
import '../comminication/dataBridgeServis.dart';
import '../screen/dashboard/dashboardController.dart';
import '../main.dart';

class AnahtarDevice extends BaseDevice {
  // Refresh animasyonu durumu
  final RxBool _isRefreshingUI = false.obs;
  final RxBool _isInteractionBlocked = false.obs;

  AnahtarDevice({
    required super.id,
    required super.name,
    required super.extension,
    required super.channel,
    required super.ico,
    required super.roomId,
    required super.instance,
  }) : super(type: 7);

  AnahtarDevice.fromMap(Map<String, dynamic> map) : super.fromMap(map);

  void _triggerRefreshAnimation() {
    _isRefreshingUI.value = true;
    Future.delayed(const Duration(milliseconds: 800), () {
      _isRefreshingUI.value = false;
    });
  }

  void _sendToOutbox(Map<String, dynamic> msg) {
    final bool forceMqtt = !isTablet.value;
    final userManager = Get.find<UserManagementService>();
    final boxIp = userManager.activeUser.value?.deviceIp;
    
    MessageOwner? receiver;
    if (boxIp != null && boxIp.isNotEmpty) {
      receiver = MessageOwner(
        transmission: TransmissionType.udp,
        ip: boxIp,
        port: 53250,
      );
    }
    
    Get.find<DataBridgeService>().send(msg, receiver: receiver, forceMqtt: forceMqtt);
  }

  @override
  Widget buildWidget() {
    final theme = Get.theme;

    return Obx(() {
      return DeviceCardBase(
        name: name ?? 'Anahtar',
        id: id,
        roomId: roomId,
        isOn: false, // Anahtar cihazının kendisi On/Off değil, alt cihazları var
        isBlocked: _isInteractionBlocked.value,
        isRefreshing: _isRefreshingUI.value,
        onTap: () => _showInstancesDialog(),
        onLongPress: () => _showRenameDialog(),
        icon: Icon(
          Icons.account_tree_outlined,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          size: 70,
        ),
      );
    });
  }

  void _showInstancesDialog() {
    final userManager = Get.find<UserManagementService>();
    final theme = Get.theme;

    String getTargetDescription(InsIntroScn ins) {
      if (ins.cm < 0 || ins.cm >= getcommandtype.length) return "";
      String typeStr = getcommandtype[ins.cm].name;
      String nameStr = "";

      switch (ins.cm) {
        case 0: // Lamba
          final dev = userManager.activeDevices.firstWhereOrNull((d) => d.id == ins.cmadr);
          nameStr = dev?.name ?? "Cihaz ${ins.cmadr}";
          break;
        case 1: // Grup
          final grp = userManager.activeGroups.firstWhereOrNull((g) => g.id == ins.cmadr);
          nameStr = grp?.name ?? "Grup ${ins.cmadr}";
          break;
        case 2: // Senaryo
          final scn = userManager.activeScenes.firstWhereOrNull((s) => s.id == ins.cmadr);
          nameStr = scn?.name ?? "Senaryo ${ins.cmadr}";
          break;
        case 3: // Anahtar
          final sw = userManager.activeSwitches.firstWhereOrNull((s) => s.id == ins.cmadr);
          nameStr = sw?.name ?? "Anahtar ${ins.cmadr}";
          break;
      }
      return "$typeStr: $nameStr";
    }
    
    Get.dialog(
      AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          name ?? 'Anahtar',
          style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: SizedBox(
          width: 600, // Popup genişliği daha da artırıldı
          child: Obx(() {
            final instances = userManager.activeInsIntroList.where((ins) => ins.adr == id).toList();

            if (instances.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "Alt cihaz bulunamadı.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                ),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.8, // Kartlar daha yüksek yapıldı
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemCount: instances.length,
              itemBuilder: (context, index) {
                final ins = instances[index];
                final info = _getInstanceInfo(ins.type);
                final bool isEnabled = ins.act == 1;
                
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface,
                    foregroundColor: theme.colorScheme.primary,
                    elevation: 3,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
                    ),
                  ),
                  onPressed: () => _handleInstanceTap(ins),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Icon(info.icon, size: 40), // İkon devasa yapıldı
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${info.label} ${ins.adr}:${ins.iadr}",
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), // Yazı devasa yapıldı
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isEnabled ? "Aktif" : "Pasif",
                              style: TextStyle(
                                fontSize: 16, // Durum yazısı büyütüldü
                                fontWeight: FontWeight.bold,
                                color: isEnabled ? Colors.green : Colors.redAccent,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              getTargetDescription(ins),
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ),
        actionsPadding: const EdgeInsets.symmetric(vertical: 10),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              buildBottomIconButton(Icons.read_more, "Özellik Oku", Colors.blue, () {
                _sendToOutbox({"com": "get_instance", "adres": id, "kanal": channel});
              }, iconSize: 40, fontSize: 15),
              buildBottomIconButton(Icons.settings_input_component, "Mode", theme.colorScheme.primary, () {
                final instances = userManager.activeInsIntroList.where((ins) => ins.adr == id).toList();
                if (instances.isNotEmpty) {
                  _showModeWindow(instances.first);
                }
              }, iconSize: 40, fontSize: 15),
              buildBottomIconButton(Icons.check_circle_outline, "Kayıt", Colors.green, () {
                _sendToOutbox({
                  "com": "put_dev",
                  "id": id,
                  "kanal": channel
                });
                Get.back();
                Get.snackbar("Başarılı", "Cihaz ayarları kaydedildi.");
              }, iconSize: 40, fontSize: 15),
              buildBottomIconButton(Icons.cancel_outlined, "Kapat", Colors.red, () {
                Get.back();
              }, iconSize: 40, fontSize: 15),
            ],
          ),
        ],
      ),
    );
  }

  _InstanceDisplayInfo _getInstanceInfo(int type) {
    switch (type) {
      case 1:
        return _InstanceDisplayInfo(Icons.touch_app_outlined, "Anahtar");
      case 2:
        return _InstanceDisplayInfo(Icons.lightbulb_outline, "Dim Anahtar");
      case 3:
        return _InstanceDisplayInfo(Icons.motion_photos_on_outlined, "Hareket");
      case 4:
        return _InstanceDisplayInfo(Icons.light_mode_outlined, "Işık");
      case 5:
        return _InstanceDisplayInfo(Icons.sensors_outlined, "Genel");
      case 6:
        return _InstanceDisplayInfo(Icons.thermostat_outlined, "Isı");
      default:
        return _InstanceDisplayInfo(Icons.extension_outlined, "Birim");
    }
  }

  void _handleInstanceTap(InsIntroScn ins) {
    switch (ins.type) {
      case 1:
      case 2:
        showSwitchConfigPopup(id, channel, ins);
        break;
      case 3:
        showMotionConfigPopup(id, channel, ins);
        break;
      case 4:
        showLuxPopup(ins);
        break;
      case 5:
        showTempPopup(id, channel, ins, label: "Genel");
        break;
      case 6:
        showTempPopup(id, channel, ins, label: "Isı");
        break;
      default:
        Get.snackbar("Bilgi", "Instance ${ins.iadr} (Tip: ${ins.type}) seçildi.");
    }
  }

  void _showModeWindow(InsIntroScn ins) {
    final theme = Get.theme;
    final RxBool isLoading = true.obs;
    final RxBool isTimeout = false.obs;
    final RxInt selectedMode = 0.obs;
    final List<String> modes = ["Kontroller ile çalış", "Bağımsız çalış"];

    void fetchData() {
      isLoading.value = true;
      isTimeout.value = false;
      _sendToOutbox({"com": "get_amode", "adr": id, "kanal": channel});
      
      Timer(const Duration(seconds: 3), () {
        if (isLoading.value) {
          isLoading.value = false;
          isTimeout.value = true;
        }
      });
    }

    fetchData();

    final subscription = Get.find<DataBridgeService>().dataStream.listen((data) {
      final payload = data['full_payload'];
      if (payload is Map && payload['com'] == 'get_amode' && payload['adr'] == id) {
        int mode = int.tryParse(payload['mode']?.toString() ?? '0') ?? 0;
        selectedMode.value = mode;
        isLoading.value = false;
        isTimeout.value = false;
      }
    });

    Get.dialog(
      AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: const Text("Çalışma Modu", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        content: Obx(() {
          if (isLoading.value) {
            return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
          }
          if (isTimeout.value) {
            return const SizedBox(
              height: 100,
              child: Center(
                child: Text("Cevap gelmedi", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            );
          }
          return SizedBox(
            width: 250,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(modes.length, (index) {
                return RadioListTile<int>(
                  title: Text(modes[index], style: const TextStyle(fontSize: 14)),
                  value: index,
                  groupValue: selectedMode.value,
                  onChanged: (val) => selectedMode.value = val!,
                );
              }),
            ),
          );
        }),
        actions: [
          Obx(() => Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              buildBottomIconButton(Icons.refresh, "Yenile", Colors.blueGrey, () {
                fetchData();
              }),
              if (!isTimeout.value && !isLoading.value)
                buildBottomIconButton(Icons.check_circle_outline, "Kaydet", Colors.green, () {
                  _sendToOutbox({
                    "com": "set_amode",
                    "adr": id,
                    "kanal": channel,
                    "mode": selectedMode.value
                  });
                  Get.back();
                  Get.snackbar("Başarılı", "Mod güncellendi.");
                }),
              buildBottomIconButton(Icons.cancel_outlined, isTimeout.value ? "Kapat" : "İptal", Colors.red, () {
                Get.back();
              }),
            ],
          )),
        ],
      ),
    ).then((_) {
      subscription.cancel();
    });
  }

  void _showRenameDialog() {
    final theme = Get.theme;
    final TextEditingController nameController = TextEditingController(text: name);

    Get.defaultDialog(
      backgroundColor: theme.scaffoldBackgroundColor,
      title: 'rename'.tr,
      titleStyle: TextStyle(color: theme.colorScheme.onSurface),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: TextField(
          controller: nameController,
          autofocus: true,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'name_hint'.tr,
            hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3))),
          ),
        ),
      ),
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary),
        onPressed: () {
          if (nameController.text.isNotEmpty) {
            final newName = nameController.text;
            this.name = newName;
            Get.find<UserManagementService>().updateDeviceName(id, channel, newName);
            // save_dev komutu gerekirse burada gönderilebilir
            Get.back();
          }
        },
        child: Text('save'.tr, style: const TextStyle(color: Colors.white)),
      ),
      cancel: OutlinedButton(
        onPressed: () => Get.back(),
        child: Text('cancel'.tr, style: TextStyle(color: theme.colorScheme.primary)),
      ),
    );
  }

  @override
  void handleIncomingValue(dynamic value) {
    _triggerRefreshAnimation();
  }
}

class _InstanceDisplayInfo {
  final IconData icon;
  final String label;
  _InstanceDisplayInfo(this.icon, this.label);
}
