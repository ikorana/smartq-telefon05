import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:telefon05/theme/app_colors.dart';
import 'base.dart';
import '../user/userManagementService.dart';
import '../comminication/comminication.dart' hide DeviceType;
import '../comminication/dataBridgeServis.dart';
import '../screen/dashboard/dashboardController.dart';
import '../main.dart'; 

import 'device_card_base.dart';

class LButtonDevice extends BaseDevice {
  final int sensorId;
  final int sensorInstance;
  final int relayId;
  final int relayChannel;
  final RxInt level = 0.obs;
  final RxBool isBusy = false.obs;
  final RxBool _isRefreshingUI = false.obs;
  Timer? _busyTimer;

  double LampWith = 85.0;

  LButtonDevice({
    required super.id,
    required super.name,
    required super.type,
    required super.extension,
    required super.channel,
    required super.ico,
    required super.roomId,
    required super.instance,
    required this.sensorId,
    required this.sensorInstance,
    required this.relayId,
    required this.relayChannel,
    int level = 0,
  }) {
    this.level.value = level;
  }

  factory LButtonDevice.fromMap(Map<String, dynamic> map) {
    return LButtonDevice(
      id: map['id'] ?? map['gr'] ?? 0,
      name: map['nm'] ?? "",
      type: map['tp'] ?? 0,
      extension: map['ex'] ?? 0,
      channel: map['rel_chn'] ?? map['pr'] ?? 0,
      ico: map['ico'] ?? 0,
      roomId: map['room'] ?? map['vr'] ?? 255,
      instance: map['sens_ins'] ?? map['in'] ?? 0,
      sensorId: map['sens_id'] ?? 0,
      sensorInstance: map['sens_ins'] ?? 0,
      relayId: map['rel_id'] ?? 0,
      relayChannel: map['rel_chn'] ?? 0,
      level: map['level'] ?? 0,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'level': level.value,
      'sens_id': sensorId,
      'sens_ins': sensorInstance,
      'rel_id': relayId,
      'rel_chn': relayChannel,
    });
    return map;
  }

  void _triggerRefreshAnimation() {
    _isRefreshingUI.value = true;
    Future.delayed(const Duration(milliseconds: 800), () {
      _isRefreshingUI.value = false;
    });
  }

  void _triggerBusy() {
    isBusy.value = true;
    _busyTimer?.cancel();
    _busyTimer = Timer(const Duration(seconds: 10), () {
      isBusy.value = false;
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
      final bool isOn = level.value > 0;

      return DeviceCardBase(
        name: name ?? "Anahtar",
        id: id,
        roomId: roomId,
        channel: channel,
        isOn: isOn,
        isBlocked: isBusy.value,
        isRefreshing: _isRefreshingUI.value,
        onTap: () {
          if (isOn) {
            _sendToOutbox({"com": "an_off", "id": id});
          } else {
            _sendToOutbox({"com": "an_on", "id": id});
          }
          _triggerBusy();
        },
        onLongPress: () => _showDetailDialog(),
        icon: Image.asset(
          isOn ? 'assets/images/anahtar1.png' : 'assets/images/anahtar2.png',
          width: 70,
          height: 70,
          errorBuilder: (context, error, stackTrace) => Icon(
            _getIcon(),
            color: isOn ? Colors.orangeAccent : theme.colorScheme.onSurface.withValues(alpha: 0.2),
            size: 60,
          ),
        ),
      );
    });
  }

  void _showDetailDialog() {
    _sendToOutbox({"com": "an_level", "id": id});

    final theme = Get.theme;
    final userManager = Get.find<UserManagementService>();
    RxInt tempLevel = level.value.obs;
    final worker = ever(level, (int val) {
      tempLevel.value = val;
    });

    // Dialog genişliği zaten isTablet.value ile Get.width/2'ye ayarlanıyor;
    // ikon/yazı boyutu için de aynı büyüklük mantığını (iconScale) kullanıyoruz.
    final double iconScale = isTablet.value ? (Get.width / 2 / 350).clamp(1.0, 1.6) : 1.0;

    Get.dialog(
      Dialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        child: SizedBox(
          width: isTablet.value ? Get.width / 2 : null,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          id.toString(),
                          style: TextStyle(color: theme.colorScheme.primary, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Obx(() => Text(
                          name ?? 'Anahtar',
                          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                        )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Obx(() => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTopBarIconBtn(Icons.edit_note, 'rename'.tr, isBusy.value ? () {} : () => _showRenameDialog(), scale: iconScale),
                      _buildTopBarIconBtn(Icons.meeting_room_outlined, 'change_room'.tr, isBusy.value ? () {} : () => _showRoomSelectionDialog(), scale: iconScale),
                    ],
                  )),
                  const Divider(),
                  // --- ODA BİLGİSİ ---
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: Obx(() {
                      final room = userManager.activeRooms.firstWhereOrNull((r) => r.id == roomId);
                      return _buildInfoChip(Icons.meeting_room, room?.name ?? 'unassigned_room'.tr, theme);
                    }),
                  ),
                  const SizedBox(height: 10),
                  Obx(() {
                    final bool isActive = tempLevel.value > 0;
                    final bool busy = isBusy.value;
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? Colors.orange.withOpacity(0.1) : Colors.black12,
                      ),
                      child: busy 
                        ? const SizedBox(width: 60, height: 60, child: CircularProgressIndicator(strokeWidth: 4, color: Colors.orange))
                        : Image.asset(
                            isActive ? 'assets/images/anahtar1.png' : 'assets/images/anahtar2.png',
                            width: 60, height: 60,
                            errorBuilder: (context, error, stackTrace) => Icon(_getIcon(), size: 60, color: isActive ? Colors.orange : theme.colorScheme.onSurface.withOpacity(0.2)),
                          ),
                    );
                  }),
                  const SizedBox(height: 20),
                  Obx(() => AbsorbPointer(
                    absorbing: isBusy.value,
                    child: Column(
                      children: [
                        Text("%${((tempLevel.value / 254) * 100).toInt()}", style: TextStyle(color: theme.colorScheme.primary, fontSize: 20, fontWeight: FontWeight.bold)),
                        Slider(
                          value: tempLevel.value.toDouble().clamp(0, 254),
                          min: 0, max: 254,
                          onChanged: (v) => tempLevel.value = v.toInt(),
                          onChangeEnd: (v) {
                            _sendToOutbox({"com": "an_power", "id": id, "power": v.toInt()});
                            _triggerBusy();
                          },
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 10),
                  Obx(() => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(child: _buildActionBtn(Icons.power_settings_new, 'open'.tr, isBusy.value ? () {} : () { _sendToOutbox({"com": "an_on", "id": id}); _triggerBusy(); }, color: Colors.green)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildActionBtn(Icons.power_settings_new, 'close'.tr, isBusy.value ? () {} : () { _sendToOutbox({"com": "an_off", "id": id}); _triggerBusy(); }, color: Colors.red)),
                    ],
                  )),
                  const SizedBox(height: 20),
                  TextButton(onPressed: () => Get.back(), child: Text("close".tr.toUpperCase(), style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
          ),
        ),
      ),
    ).then((_) => worker.dispose());
  }

  Widget _buildInfoChip(IconData icon, String label, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarIconBtn(IconData icon, String label, VoidCallback onTap, {double scale = 1.0}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.all(4.0 * scale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 23 * scale, color: Get.theme.colorScheme.onSurface.withValues(alpha: 0.8)),
            SizedBox(height: 4 * scale),
            Text(label, style: TextStyle(fontSize: 10 * scale, color: Get.theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Get.theme.colorScheme.surface,
        foregroundColor: color ?? Get.theme.colorScheme.primary,
        elevation: 1,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      ),
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showRenameDialog() {
    final TextEditingController nameController = TextEditingController(text: name);
    Get.defaultDialog(
      backgroundColor: Get.theme.scaffoldBackgroundColor,
      title: 'rename'.tr,
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: TextField(
          controller: nameController,
          autofocus: true,
          style: TextStyle(color: Get.theme.colorScheme.onSurface),
          decoration: InputDecoration(hintText: 'name_hint'.tr, enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Get.theme.colorScheme.primary.withValues(alpha: 0.3)))),
        ),
      ),
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Get.theme.colorScheme.primary),
        onPressed: () {
          if (nameController.text.isNotEmpty) {
            final newName = nameController.text;
            name = newName;
            Get.find<UserManagementService>().updateSwitchName(id, newName);
            _sendToOutbox({"com": "an_save", "id": id, "nm": newName, "room": roomId});
            Get.back();
          }
        },
        child: Text('save'.tr, style: const TextStyle(color: Colors.white)),
      ),
      cancel: OutlinedButton(onPressed: () => Get.back(), child: Text('cancel'.tr)),
    );
  }

  void _showRoomSelectionDialog() {
    final userManager = Get.find<UserManagementService>();
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Get.theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('rooms'.tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: userManager.activeRooms.length,
                itemBuilder: (context, index) {
                  final room = userManager.activeRooms[index];
                  return ListTile(
                    leading: Icon(Icons.meeting_room_outlined, color: Get.theme.colorScheme.primary),
                    title: Text(room.name),
                    onTap: () {
                      roomId = room.id;
                      userManager.updateSwitchRoom(id, room.id);
                      _sendToOutbox({"com": "an_save", "id": id, "nm": name, "room": room.id});
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

  IconData _getIcon() {
    switch (ico) {
      case 0: return Icons.lightbulb_outline;
      case 1: return Icons.power_settings_new;
      default: return Icons.ads_click;
    }
  }

  @override
  void handleIncomingValue(dynamic value) {
    _triggerRefreshAnimation();

    if (value is Map) {
      if ((value['com'] == 'an_okey') && value['id'] == id) {
        isBusy.value = false;
        _busyTimer?.cancel();
      }

      if (value.containsKey('level')) {
        level.value = int.tryParse(value['level'].toString()) ?? 0;
      }
    } else if (value is int) {
      level.value = value;
    } else if (value is String) {
      level.value = int.tryParse(value) ?? 0;
    }
  }
}
