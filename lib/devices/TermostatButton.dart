import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'base.dart';
import '../user/userManagementService.dart';
import '../comminication/comminication.dart' hide DeviceType;
import '../comminication/dataBridgeServis.dart';
import '../main.dart'; 

import 'device_card_base.dart';

class ThermostatDevice extends BaseDevice {
  final RxInt rxLevel = 0.obs;
  final RxnInt rxSetPoint = RxnInt();
  final RxInt rxRelayStatus = 0.obs;
  final RxInt rxErrorStatus = 0.obs;
  final RxInt rxWorkType = 0.obs; // 0: Isıtma, 1: Soğutma, 2: Manuel ON, 3: Manuel OFF

  int get level => rxLevel.value;
  set level(int val) => rxLevel.value = val;

  int? get setPoint => rxSetPoint.value;
  set setPoint(int? val) => rxSetPoint.value = val;

  int get relayStatus => rxRelayStatus.value;
  set relayStatus(int val) => rxRelayStatus.value = val;

  int get errorStatus => rxErrorStatus.value;
  set errorStatus(int val) => rxErrorStatus.value = val;

  int get workType => rxWorkType.value;
  set workType(int val) => rxWorkType.value = val;

  final int sensorId;
  final int sensorInstance;
  final int relayId;
  final int relayChannel;
  bool _isInitialFetchDone = false;

  ThermostatDevice({
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
    int? setPoint,
    int relayStatus = 0,
    int errorStatus = 0,
    int workType = 0,
  }) {
    this.level = level;
    this.setPoint = setPoint;
    this.relayStatus = relayStatus;
    this.errorStatus = errorStatus;
    this.workType = workType;
  }

  factory ThermostatDevice.fromMap(Map<String, dynamic> map) {
    return ThermostatDevice(
      id: map['id'] ?? map['gr'] ?? 0,
      name: map['nm'] ?? "",
      type: map['tp'] ?? 3,
      extension: map['ex'] ?? 0,
      channel: map['rel_chn'] ?? map['pr'] ?? 0,
      ico: map['ico'] ?? 0,
      roomId: map['room'] ?? map['vr'] ?? 255,
      instance: map['sens_ins'] ?? map['in'] ?? 0,
      sensorId: map['sens_id'] ?? 0,
      sensorInstance: map['sens_ins'] ?? 0,
      relayId: map['rel_id'] ?? 0,
      relayChannel: map['rel_chn'] ?? 0,
      level: map['level'] ?? map['temp'] ?? 0,
      setPoint: map['set'] is int? ? map['set'] : (map['set'] != null ? int.tryParse(map['set'].toString()) : null),
      relayStatus: int.tryParse((map['relay'] ?? '0').toString()) ?? 0,
      errorStatus: int.tryParse((map['error'] ?? '0').toString()) ?? 0,
      workType: map['ttpe'] is int ? map['ttpe'] : int.tryParse(map['ttpe']?.toString() ?? '0') ?? 0,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'level': level,
      'set': setPoint,
      'sens_id': sensorId,
      'sens_ins': sensorInstance,
      'rel_id': relayId,
      'rel_chn': relayChannel,
      'relay': relayStatus,
      'error': errorStatus,
      'ttpe': workType,
    });
    return map;
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
            name = newName;

            Get.find<UserManagementService>().updateSwitchName(id, newName);
             _sendToOutbox({
              "com": "an_save",
              "id": id,
              "nm": newName,
              "room": roomId
            });
            
            Get.back();
            Get.back();
            _showDetailDialog(context);
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
            Text('rooms'.tr,
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
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
                      roomId = room.id;
                      userManager.updateSwitchRoom(id, room.id);
                       _sendToOutbox({
                        "com": "an_save",
                        "id": id,
                        "nm": name,
                        "room": room.id
                      });
                      
                      Get.back();
                      Get.back();
                      _showDetailDialog(context);
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

  void _showModeSelectionDialog(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget buildModeItem(IconData icon, Color color, String label, int mode) {
      return Obx(() {
        final isSelected = workType == mode;
        return ListTile(
          leading: Icon(icon, color: isSelected ? color : color.withValues(alpha: 0.5)),
          title: Text(label, style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
          )),
          trailing: isSelected ? Icon(Icons.check_circle, color: theme.colorScheme.primary) : null,
          onTap: () {
            Get.back();
            _confirmModeChange(context, mode, label);
          },
        );
      });
    }

    Get.defaultDialog(
      title: 'select_mode'.tr,
      backgroundColor: theme.scaffoldBackgroundColor,
      titleStyle: TextStyle(color: theme.colorScheme.onSurface),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildModeItem(Icons.local_fire_department, Colors.orange, 'heating_mode'.tr, 0),
          buildModeItem(Icons.ac_unit, Colors.blue, 'cooling_mode'.tr, 1),
          buildModeItem(Icons.power, Colors.green, 'manual_on'.tr, 2),
          buildModeItem(Icons.power_off, Colors.grey, 'manual_off'.tr, 3),
        ],
      ),
    );
  }

  void _confirmModeChange(BuildContext context, int mode, String modeName) {
    Get.defaultDialog(
      title: 'select_mode'.tr,
      middleText: 'mode_confirm'.trParams({'mode': modeName}),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      textConfirm: 'yes'.tr,
      textCancel: 'no'.tr,
      confirmTextColor: Colors.white,
      buttonColor: Theme.of(context).colorScheme.primary,
      onConfirm: () {
        _sendToOutbox({
          "com": "set_tmode",
          "adres": sensorId,
          "ins": sensorInstance,
          "kanal": channel,
          "mode": mode
        });
        workType = mode;
        Get.back();
      },
    );
  }

  void _showDetailDialog(BuildContext context) {
    final theme = Theme.of(context);
    final RxInt tempSetPoint = (setPoint ?? 22).clamp(16, 45).obs;

    final worker = ever(rxSetPoint, (int? val) {
      if (val != null) {
        tempSetPoint.value = val.clamp(16, 45);
      }
    });

    _sendToOutbox({"com": "get_temp", "adres": sensorId, "ins": sensorInstance, "kanal": channel});
    
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
                          name ?? 'termostat'.tr,
                          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                        )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTopBarIconBtn(Icons.edit_note, 'rename'.tr, () => _showRenameDialog(context)),
                      _buildTopBarIconBtn(Icons.meeting_room_outlined, 'change_room'.tr, () => _showRoomSelectionDialog(context)),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),
                  Obx(() {
                    final bool hasError = errorStatus == 1;
                    final bool isHeatingMode = workType == 0;
                    final bool isActive = workType == 2 || (isHeatingMode ? (level < tempSetPoint.value) : (workType == 1 && level > tempSetPoint.value));
                    
                    Color dialColor = isActive ? Colors.orange : Colors.blue;
                    if (hasError) dialColor = Colors.grey;
                    else if (workType == 2) dialColor = relayStatus == 1 ? Colors.red : Colors.green;
                    else if (workType == 3) dialColor = Colors.grey;

                    return AbsorbPointer(
                      absorbing: hasError,
                      child: Opacity(
                        opacity: hasError ? 0.5 : 1.0,
                        child: CircularTempSlider(
                          value: tempSetPoint.value.toDouble(),
                          currentTemp: level.toDouble(),
                          min: 16,
                          max: 45,
                          onChanged: (val) {
                            tempSetPoint.value = val.toInt();
                          },
                          onChangeEnd: (val) {
                            _sendToOutbox({
                              "com": "set_temp",
                              "adres": sensorId,
                              "ins": sensorInstance,
                              "kanal": channel,
                              "set": val.toInt(),
                            });
                          },
                          activeColor: dialColor,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                  Obx(() {
                    final bool hasError = errorStatus == 1;
                    
                    IconData statusIcon;
                    Color statusIconColor;

                    if (workType == 0) {
                      statusIcon = Icons.local_fire_department;
                      statusIconColor = relayStatus == 1 ? Colors.red : theme.colorScheme.onSurface.withValues(alpha: 0.2);
                    } else if (workType == 1) {
                      statusIcon = Icons.ac_unit;
                      statusIconColor = relayStatus == 1 ? Colors.red : theme.colorScheme.onSurface.withValues(alpha: 0.2);
                    } else if (workType == 2) {
                      statusIcon = Icons.power;
                      statusIconColor = relayStatus == 1 ? Colors.red : Colors.green;
                    } else {
                      statusIcon = Icons.power_off;
                      statusIconColor = Colors.grey;
                    }
                    
                    if (hasError) {
                      return Text(
                        'sensor_error'.tr,
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            Text("current".tr.toUpperCase(), style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                            Text("$level°C", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Icon(
                          statusIcon, 
                          color: statusIconColor,
                          size: 32,
                        ),
                        const SizedBox(width: 20),
                        Column(
                          children: [
                            Text("target".tr.toUpperCase(), style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                            Text("${tempSetPoint.value}°C", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: statusIconColor)),
                          ],
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 20),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildBottomIconWithLabel(Icons.refresh, 'refresh'.tr, () {
                           _sendToOutbox({"com": "get_temp", "adres": sensorId, "ins": sensorInstance, "kanal": channel});
                        }),
                        Obx(() {
                          IconData modeBtnIcon;
                          Color modeBtnColor;
                          if (workType == 0) {
                            modeBtnIcon = Icons.local_fire_department;
                            modeBtnColor = Colors.orange;
                          } else if (workType == 1) {
                            modeBtnIcon = Icons.ac_unit;
                            modeBtnColor = Colors.blue;
                          } else if (workType == 2) {
                            modeBtnIcon = Icons.power;
                            modeBtnColor = Colors.green;
                          } else {
                            modeBtnIcon = Icons.power_off;
                            modeBtnColor = Colors.grey;
                          }

                          return _buildBottomIconWithLabel(
                            modeBtnIcon, 
                            'mode'.tr, 
                            () => _showModeSelectionDialog(context),
                            iconColor: modeBtnColor,
                          );
                        }),
                      ],
                    ),
                  ),
                  const Divider(),
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text("close".tr, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).then((_) => worker.dispose());
  }

  Widget _buildTopBarIconBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: Get.theme.colorScheme.onSurface.withValues(alpha: 0.8)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 8, color: Get.theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomIconWithLabel(IconData icon, String label, VoidCallback onTap, {Color? iconColor}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: iconColor ?? Get.theme.colorScheme.onSurface.withValues(alpha: 0.7)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 8, color: Get.theme.colorScheme.onSurface.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  @override
  Widget buildWidget() {
    final theme = Get.theme;

    return Obx(() {
      final bool hasError = errorStatus == 1;

      IconData modeIcon;
      Color statusColor;
      Color modeIconColor;

      if (workType == 0) {
        modeIcon = Icons.local_fire_department;
        final bool isActive = level < (setPoint ?? 0);
        statusColor = isActive ? Colors.orange : Colors.blue;
        modeIconColor = relayStatus == 1 ? Colors.red : theme.colorScheme.onSurface.withValues(alpha: 0.1);
      } else if (workType == 1) {
        modeIcon = Icons.ac_unit;
        final bool isActive = level > (setPoint ?? 0);
        statusColor = isActive ? Colors.orange : Colors.blue;
        modeIconColor = relayStatus == 1 ? Colors.red : theme.colorScheme.onSurface.withValues(alpha: 0.1);
      } else if (workType == 2) {
        modeIcon = Icons.power;
        statusColor = Colors.green;
        modeIconColor = relayStatus == 1 ? Colors.red : Colors.green;
      } else {
        modeIcon = Icons.power_off;
        statusColor = Colors.grey;
        modeIconColor = theme.colorScheme.onSurface.withValues(alpha: 0.2);
      }

      return DeviceCardBase(
        name: name ?? 'termostat'.tr,
        id: id,
        roomId: roomId,
        isOn: relayStatus == 1,
        isBlocked: false,
        isRefreshing: false,
        width: 300,
        onTap: () => _showDetailDialog(Get.context!),
        onLongPress: () => _showDetailDialog(Get.context!),
        icon: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasError) ...[
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 50),
              const SizedBox(height: 4),
              Text('sensor_error'.tr,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
            ] else ...[
              // Ana Sıcaklık ve İkonlar Satırı
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.thermostat, color: statusColor, size: 52),
                  const SizedBox(width: 15),
                  Text(
                    "$level°C",
                    style: TextStyle(
                      fontSize: 38, 
                      fontWeight: FontWeight.bold, 
                      color: statusColor,
                      height: 1.1, // Metin dikey hizalamasını iyileştirir
                    ),
                  ),
                  const SizedBox(width: 25),
                  Icon(modeIcon, color: modeIconColor, size: 52),
                ],
              ),
              // Hedef Sıcaklık (Varsa)
              if (setPoint != null && workType < 2) ...[
                const SizedBox(height: 2),
                Text(
                  "${'set'.tr}: $setPoint°C",
                  style: TextStyle(
                    fontSize: 18,
                    color: relayStatus == 1 ? Colors.orange.shade800 : statusColor.withValues(alpha: 0.8),
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ],
            ],
          ],
        ),
      );
    });
  }

  @override
  void handleIncomingValue(dynamic value) {
    if (value is Map) {
      if (value.containsKey('temp')) { level = int.tryParse(value['temp'].toString()) ?? level; }
      else if (value.containsKey('level')) { level = int.tryParse(value['level'].toString()) ?? level; }

      if (value.containsKey('set')) { setPoint = int.tryParse(value['set'].toString()); }

      if (value.containsKey('relay')) { relayStatus = int.tryParse(value['relay'].toString()) ?? relayStatus; }

      if (value.containsKey('error')) { errorStatus = int.tryParse(value['error'].toString()) ?? errorStatus; }

      if (value.containsKey('type')) { workType = int.tryParse(value['type'].toString()) ?? workType; }
      else if (value.containsKey('ttpe')) { workType = int.tryParse(value['ttpe'].toString()) ?? workType; }
    } else if (value is int) {
      level = value;
    }
  }
}

class CircularTempSlider extends StatelessWidget {
  final double value;
  final double currentTemp;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final Color activeColor;

  const CircularTempSlider({
    super.key,
    required this.value,
    required this.currentTemp,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
    this.activeColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        final center = box.size.center(Offset.zero);
        final pos = details.localPosition - center;
        final angle = atan2(pos.dy, pos.dx);
        double normalizedAngle = angle + pi / 2;
        if (normalizedAngle < 0) normalizedAngle += 2 * pi;
        final newValue = min + (normalizedAngle / (2 * pi)) * (max - min);
        onChanged(newValue.clamp(min, max));
      },
      onPanEnd: (_) => onChangeEnd(value),
      child: CustomPaint(
        size: const Size(200, 200),
        painter: _CircularSliderPainter(
          value: value,
          currentTemp: currentTemp,
          min: min,
          max: max,
          activeColor: activeColor,
          theme: Theme.of(context),
        ),
      ),
    );
  }
}

class _CircularSliderPainter extends CustomPainter {
  final double value;
  final double currentTemp;
  final double min;
  final double max;
  final Color activeColor;
  final ThemeData theme;

  _CircularSliderPainter({
    required this.value,
    required this.currentTemp,
    required this.min,
    required this.max,
    required this.activeColor,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    const strokeWidth = 12.0;

    final bgPaint = Paint()
      ..color = theme.colorScheme.onSurface.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius - strokeWidth, bgPaint);

    final progressPaint = Paint()
      ..color = activeColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    final sweepAngle = ((value - min) / (max - min)) * pi * 2;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - strokeWidth), -pi / 2, sweepAngle, false, progressPaint);

    final clampedCurrentTemp = currentTemp.clamp(min, max);
    final currentAngle = ((clampedCurrentTemp - min) / (max - min)) * 2 * pi - pi / 2;
    final currentPos = center + Offset(cos(currentAngle), sin(currentAngle)) * (radius - strokeWidth);
    canvas.drawCircle(currentPos, 4, Paint()..color = theme.colorScheme.onSurface.withValues(alpha: 0.3));

    final handleAngle = sweepAngle - pi / 2;
    final handlePos = center + Offset(cos(handleAngle), sin(handleAngle)) * (radius - strokeWidth);
    canvas.drawCircle(handlePos, 14, Paint()..color = activeColor.withValues(alpha: 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(handlePos, 12, Paint()..color = activeColor);
    canvas.drawCircle(handlePos, 6, Paint()..color = Colors.white);

    final textPainter = TextPainter(text: TextSpan(text: "${value.toInt()}°C", style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: activeColor)), textDirection: TextDirection.ltr)..layout();
    textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));

    final targetLabelPainter = TextPainter(text: TextSpan(text: "target".tr.toUpperCase(), style: TextStyle(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))), textDirection: TextDirection.ltr)..layout();
    targetLabelPainter.paint(canvas, center - Offset(targetLabelPainter.width / 2, textPainter.height / 2 + 15));
  }

  @override
  bool shouldRepaint(covariant _CircularSliderPainter oldDelegate) => true;
}
