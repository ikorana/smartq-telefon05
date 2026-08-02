import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:telefon05/theme/app_colors.dart';
import 'base.dart';
import 'ins_ui_helper.dart';
import 'ins_anahtar.dart';
import 'ins_hareket.dart';
import 'ins_temp.dart';
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
    sendToOutbox(msg);
  }

  @override
  Widget buildWidget() {
    final theme = Get.theme;
    final controller = Get.find<DashboardController>();

    return Obx(() {
      final bool isBlocked = _isInteractionBlocked.value;
      final bool isRefreshing = _isRefreshingUI.value;
      
      final bool isAllRooms = controller.selectedRoomId.value == null;
      final bool hasRoom = roomId != 255;

      Color borderColor = Colors.transparent;
      double borderWidth = 1.2;
      List<BoxShadow> shadows = [];

      if (isRefreshing) {
        borderColor = theme.colorScheme.primary;
        borderWidth = 2.5;
        shadows.add(
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 4,
          )
        );
      } else if (isBlocked) {
        borderColor = Colors.blue.withValues(alpha: 0.5);
        borderWidth = 1.5;
      }

      return Container(
        width: 85,
        height: btnHigh.value,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isBlocked ? null : () => _showInstancesDialog(),
            onLongPress: isBlocked ? null : () => _showRenameDialog(Get.context!),
            borderRadius: BorderRadius.circular(15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 85,
                  height: btnIcoHigh.value,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: borderColor,
                      width: borderWidth,
                    ),
                    boxShadow: shadows,
                  ),
                  child: Center(
                    child: isBlocked
                        ? const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                          )
                        : Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                Icons.account_tree_outlined,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                                size: 45,
                              ),
                              if (isAllRooms && hasRoom)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name ?? 'Anahtar',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.extension<AppColors>()?.labelText,
                    height: 1.1,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  void _showInstancesDialog() {
    final userManager = Get.find<UserManagementService>();
    final theme = Get.theme;
    
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
          width: 350,
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
                childAspectRatio: 2.2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
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
                    elevation: 1,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.2)),
                    ),
                  ),
                  onPressed: () => _handleInstanceTap(ins),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Icon(info.icon, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${info.label} ${ins.adr}:${ins.iadr}",
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              isEnabled ? "Aktif" : "Pasif",
                              style: TextStyle(
                                fontSize: 8, 
                                fontWeight: FontWeight.bold,
                                color: isEnabled ? Colors.green : Colors.redAccent,
                              ),
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
              }),
              buildBottomIconButton(Icons.settings_input_component, "Mode", theme.colorScheme.primary, () {
                final instances = userManager.activeInsIntroList.where((ins) => ins.adr == id).toList();
                if (instances.isNotEmpty) {
                  _showModeWindow(instances.first);
                }
              }),
              buildBottomIconButton(Icons.check_circle_outline, "Kayıt", Colors.green, () {
                _sendToOutbox({
                  "com": "put_dev",
                  "id": id,
                  "kanal": channel
                });
                Get.back();
                Get.snackbar("Başarılı", "Cihaz ayarları kaydedildi.");
              }),
              buildBottomIconButton(Icons.cancel_outlined, "Kapat", Colors.red, () {
                Get.back();
              }),
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

  void _showRenameDialog(BuildContext context) {
    final theme = Theme.of(context);
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
            // Burada save_dev vb. komutu gerekirse gönderin
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

  void _showRoomSelectionDialog(BuildContext context) {
    final theme = Theme.of(context);
    final userManager = Get.find<UserManagementService>();

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('rooms'.tr, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: userManager.activeRooms.length,
                itemBuilder: (context, index) {
                  final room = userManager.activeRooms[index];
                  return ListTile(
                    leading: Icon(Icons.meeting_room_outlined, color: theme.colorScheme.primary),
                    title: Text(room.name, style: TextStyle(color: theme.colorScheme.onSurface)),
                    onTap: () {
                      this.roomId = room.id;
                      userManager.updateDeviceRoom(id, channel, room.id);
                      Get.back();
                    },
                  );
                },
              ),
            ),
          ],
        ),
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
