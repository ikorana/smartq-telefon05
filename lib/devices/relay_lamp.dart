import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'base.dart';
import '../comminication/comminication.dart' hide DeviceType;
import '../comminication/dataBridgeServis.dart';
import '../user/userManagementService.dart';
import '../user/appUser.dart';
import '../main.dart';

import 'device_card_base.dart';

class RelayLampDevice extends BaseDevice {
  final Color activeColor = Colors.amber;
  final RxInt level = 0.obs;
  bool _isStatusFetched = false;
  final RxBool _isInteractionBlocked = false.obs;
  final RxInt statusBits = 0.obs;
  bool _isStatusDialogOpen = false;
  bool _isGroupsDialogOpen = false;

  final RxInt minLevel = 0.obs;
  final RxInt maxLevel = 254.obs;
  final RxInt errorLevel = 254.obs;
  final RxInt powerOnLevel = 254.obs;
  final RxInt physicalMin = 1.obs;

  final RxBool _isRefreshingUI = false.obs;

  final RxInt fadeRate = 1.obs;
  final RxInt fadeTime = 0.obs;

  final RxInt extendedFadeTimeBase = 0.obs;
  final RxInt extendedFadeTimeMultiplier = 0.obs;

  final RxInt groupLow = 0.obs;
  final RxInt groupHigh = 0.obs;

  final RxMap<int, bool> groupLoadingStates = <int, bool>{}.obs;
  final RxMap<int, int> scenarioValues = <int, int>{}.obs;

  static const List<IconData> lampIcons = [
    Icons.lightbulb,
    Icons.wb_incandescent,
    Icons.tungsten,
    Icons.highlight,
    Icons.fluorescent,
    Icons.emoji_objects,
    Icons.tips_and_updates,
    Icons.flare,
    Icons.wb_sunny,
    Icons.bedtime,
    Icons.toggle_on,
    Icons.power_settings_new,
    Icons.settings_input_component,
    Icons.outlet,
    Icons.flash_on,
    Icons.electrical_services,
  ];

  RelayLampDevice({
    required super.id,
    required super.name,
    required super.extension,
    required super.channel,
    required super.ico,
    required super.roomId,
    required super.instance,
  }) : super(type: 7);

  RelayLampDevice.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    level.value = int.tryParse(map['v']?.toString() ?? '0') ?? 0;
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map['v'] = level.value;
    return map;
  }

  void _triggerRefreshAnimation() {
    _isRefreshingUI.value = true;
    Future.delayed(const Duration(milliseconds: 800), () => _isRefreshingUI.value = false);
  }

  @override
  void handleIncomingValue(dynamic value) {
    if (value == null) return;
    _triggerRefreshAnimation();

    if (value is Map && value.containsKey('status')) {
      statusBits.value = int.tryParse(value['status'].toString()) ?? 0;
      _showStatusDialog();
      return;
    }

    if (value is Map && value.containsKey('is_passive_update')) {
      if (value.containsKey('level')) level.value = int.tryParse(value['level'].toString()) ?? level.value;
      if (value.containsKey('v')) level.value = int.tryParse(value['v'].toString()) ?? level.value;
      if (value.containsKey('low')) groupLow.value = int.tryParse(value['low'].toString()) ?? groupLow.value;
      if (value.containsKey('high')) groupHigh.value = int.tryParse(value['high'].toString()) ?? groupHigh.value;
      _isStatusFetched = true;
      return;
    }

    if (value is Map && value.containsKey('com')) {
      final String com = value['com'];
      if (com == 'get_detail') {
        minLevel.value = int.tryParse(value['min'].toString()) ?? 0;
        maxLevel.value = int.tryParse(value['max'].toString()) ?? 254;
        errorLevel.value = int.tryParse(value['fail']?.toString() ?? value['err']?.toString() ?? '254') ?? 254;
        powerOnLevel.value = int.tryParse(value['pwr'].toString()) ?? 254;
        physicalMin.value = int.tryParse(value['pmin'].toString()) ?? 1;

        int fade = int.tryParse(value['fade'].toString()) ?? 0;
        fadeTime.value = (fade >> 4) & 0x0F;
        fadeRate.value = (fade & 0x0F) + 1;

        int efade = int.tryParse(value['efade'].toString()) ?? 0;
        extendedFadeTimeMultiplier.value = (efade >> 4) & 0x0F;
        extendedFadeTimeBase.value = efade & 0x0F;
        return;
      }
    }

    if (value is Map && value.containsKey('low') && value.containsKey('high')) {
      groupLow.value = int.tryParse(value['low'].toString()) ?? 0;
      groupHigh.value = int.tryParse(value['high'].toString()) ?? 0;
      groupLoadingStates.clear();
      if (!_isGroupsDialogOpen && value['is_passive_update'] != true) _showGroupsDialog();
      return;
    }

    if (value is Map && (value.containsKey('scene_status') || value['com'] == 'set_scene')) {
      int sId = int.tryParse(value['scene']?.toString() ?? '0') ?? 0;
      int val = int.tryParse(value['value']?.toString() ?? '0') ?? 0;
      scenarioValues[sId] = val;
      if (value.containsKey('scene_status')) _showSceneValueEditDialog(sId, val);
      return;
    }

    final int? newVal = int.tryParse(value.toString());
    if (newVal != null) {
      level.value = newVal;
      _isStatusFetched = true;
    }
  }

  void _sendToOutbox(Map<String, dynamic> msg) {
    final bool forceMqtt = !isTablet.value;
    final userManager = Get.find<UserManagementService>();
    final boxIp = userManager.activeUser.value?.deviceIp;
    MessageOwner? receiver;
    if (boxIp != null && boxIp.isNotEmpty) {
      receiver = MessageOwner(transmission: TransmissionType.udp, ip: boxIp, port: 53250);
    }
    Get.find<DataBridgeService>().send(msg, receiver: receiver, forceMqtt: forceMqtt);
  }

  void _sendSaveDeviceToBox() {
    _sendToOutbox({"com": "save_dev", "id": id, "kanal": channel, "gr": id, "nm": name, "vr": roomId, "an": logicButtonId});
  }

  void _sendCommand(int val) {
    if (val == 0) _sendOffCommand();
    else _sendArcPowerCommand(val);
  }

  void _sendOffCommand() {
    _sendToOutbox({"com": "off", "adres": id, "gurup": 0, "kanal": channel});
    level.value = 0;
  }

  void _sendOpenCommand() => _sendArcPowerCommand(200);

  void _sendActionCommand() {
    if (_isInteractionBlocked.value) return;
    _isInteractionBlocked.value = true;
    _sendToOutbox({"com": "action", "adres": id, "gurup": 0, "komut": 3, "kanal": channel});
    level.value = 127;
    Future.delayed(const Duration(milliseconds: 500), () => _isInteractionBlocked.value = false);
  }

  void _sendMaxCommand() {
    _sendToOutbox({"com": "action", "adres": id, "gurup": 0, "komut": 3, "kanal": channel});
    level.value = 254;
  }

  void _sendMinCommand() {
    _sendToOutbox({"com": "action", "adres": id, "gurup": 0, "komut": 2, "kanal": channel});
    level.value = 1;
  }

  void _sendIdentifyCommand() => _sendToOutbox({"com": "identfy", "adres": id, "kanal": channel});

  void _sendArcPowerCommand(int val) {
    _sendToOutbox({"com": "arc_power", "adres": id, "gurup": 0, "power": val, "kanal": channel});
    level.value = val;
  }

  void _sendGetLevelCommand() {
    _sendToOutbox({"com": "get_level", "adres": id, "kanal": channel});
    _isStatusFetched = true;
  }

  void _sendQStatusCommand() => _sendToOutbox({"com": "qstatus", "adres": id, "kanal": channel});
  void _sendGetGroupsCommand() => _sendToOutbox({"com": "get_gurup", "adres": id, "kanal": channel});

  void _sendSetGroupsCommand(int groupId, int type) {
    groupLoadingStates[groupId] = true;
    Future.delayed(const Duration(seconds: 3), () => groupLoadingStates.remove(groupId));
    _sendToOutbox({"com": "set_gurup", "adres": id, "kanal": channel, "gurup": groupId, "type": type});
  }

  void _sendGetScenarioCommand(int scenarioId) => _sendToOutbox({"com": "get_scene", "adres": id, "kanal": channel, "scene": scenarioId});
  void _sendScenarioValueDelete(int scenarioId) => _sendToOutbox({"com": "del_scene", "adres": id, "kanal": channel, "scene": scenarioId});
  void _sendScenarioValueUpdate(int scenarioId, int val) => _sendToOutbox({"com": "set_scene", "adres": id, "kanal": channel, "scene": scenarioId, "value": val});
  void _sendDaliConfigCommand(String command, int value) => _sendToOutbox({"com": command, "adres": id, "kanal": channel, "val": value});
  void _sendDaliGetConfigCommand(String command) => _sendToOutbox({"com": command, "adres": id, "kanal": channel});

  IconData _getIconData(int index) {
    if (index == 11) return Icons.visibility_off;
    if (index >= 0 && index < lampIcons.length) return lampIcons[index];
    return Icons.lightbulb;
  }

  void _showStatusDialog() {
    if (_isStatusDialogOpen) return;
    _isStatusDialogOpen = true;
    final List<String> statusLabels = ['status_driver_error'.tr, 'status_lamp_error'.tr, 'status_lamp_on'.tr, 'status_limit_error'.tr, 'status_fade_running'.tr, 'status_reset_values'.tr, 'status_wrong_address'.tr, 'status_power_on'.tr];
    Get.dialog(AlertDialog(title: Text("${name ?? 'lamp'.tr} - ${'status'.tr}"), content: Obx(() => Column(mainAxisSize: MainAxisSize.min, children: List.generate(statusLabels.length, (index) { bool isSet = (statusBits.value & (1 << index)) != 0; return CheckboxListTile(title: Text(statusLabels[index], style: const TextStyle(fontSize: 14)), value: isSet, onChanged: null, dense: true, controlAffinity: ListTileControlAffinity.leading); }))), actions: [TextButton(onPressed: () => _sendQStatusCommand(), child: Text("refresh".tr.toUpperCase())), TextButton(onPressed: () => Get.back(), child: Text("close".tr.toUpperCase(), style: TextStyle(color: Get.theme.colorScheme.primary)))]),).then((_) => _isStatusDialogOpen = false);
  }

  void _showGroupsDialog() {
    if (_isGroupsDialogOpen) return;
    _isGroupsDialogOpen = true;
    final userManager = Get.find<UserManagementService>();
    final theme = Get.theme;
    Get.dialog(AlertDialog(title: Text("${name ?? 'lamp'.tr} - ${'groups'.tr}"), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15), content: SizedBox(width: 455, child: Obx(() { if (userManager.activeGroups.isEmpty) return Center(child: Text('no_users_found'.tr)); return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 3.2, crossAxisSpacing: 5, mainAxisSpacing: 5), itemCount: userManager.activeGroups.length, itemBuilder: (context, index) { final group = userManager.activeGroups[index]; return Obx(() { bool isSelected = group.id < 8 ? (groupLow.value & (1 << group.id)) != 0 : (groupHigh.value & (1 << (group.id - 8))) != 0; bool isLoading = groupLoadingStates[group.id] ?? false; return InkWell(onTap: isLoading ? null : () { bool newVal = !isSelected; if (group.id < 8) { if (newVal) groupLow.value |= (1 << group.id); else groupLow.value &= ~(1 << group.id); } else { int bitPos = group.id - 8; if (newVal) groupHigh.value |= (1 << bitPos); else groupHigh.value &= ~(1 << bitPos); } _sendSetGroupsCommand(group.id, newVal ? 1 : 0); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: isLoading ? theme.colorScheme.primary.withValues(alpha: 0.05) : null), child: Row(children: [SizedBox(width: 32, height: 32, child: isLoading ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)) : Checkbox(value: isSelected, onChanged: (bool? val) { if (val == null) return; if (group.id < 8) { if (val) groupLow.value |= (1 << group.id); else groupLow.value &= ~(1 << group.id); } else { int bitPos = group.id - 8; if (val) groupHigh.value |= (1 << bitPos); else groupHigh.value &= ~(1 << bitPos); } _sendSetGroupsCommand(group.id, val ? 1 : 0); }, visualDensity: VisualDensity.compact)), Expanded(child: Text(group.name, style: TextStyle(fontSize: 14, color: isLoading ? theme.colorScheme.primary.withValues(alpha: 0.5) : null), maxLines: 1, overflow: TextOverflow.ellipsis)), ], ), ), ); }); }, ); })), actions: [TextButton(onPressed: () => _sendGetGroupsCommand(), child: Text("refresh".tr.toUpperCase())), TextButton(onPressed: () => Get.back(), child: Text("close".tr.toUpperCase(), style: TextStyle(color: theme.colorScheme.primary)))]),).then((_) { _isGroupsDialogOpen = false; groupLoadingStates.clear(); });
  }

  void _showScenariosDialog() {
    final theme = Get.theme;
    final userManager = Get.find<UserManagementService>();
    Get.dialog(AlertDialog(backgroundColor: theme.scaffoldBackgroundColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: Text("${name ?? 'lamp'.tr} - ${'scenarios'.tr}", style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center), contentPadding: const EdgeInsets.fromLTRB(15, 20, 15, 10), content: SizedBox(width: 350, child: Obx(() { if (userManager.activeScenes.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text('no_users_found'.tr, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))))); return GridView.builder(shrinkWrap: true, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 3.5, crossAxisSpacing: 10, mainAxisSpacing: 10), itemCount: userManager.activeScenes.length, itemBuilder: (context, index) { final scene = userManager.activeScenes[index]; return ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.surface, foregroundColor: theme.colorScheme.onSurface, elevation: 1, padding: const EdgeInsets.symmetric(horizontal: 4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.withValues(alpha: 0.5)))), onPressed: () { _sendGetScenarioCommand(scene.id); _showSceneValueEditDialog(scene.id, scenarioValues[scene.id] ?? 0); }, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(scene.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis), Obx(() { final val = scenarioValues[scene.id]; if (val == null) return const SizedBox.shrink(); return Text("Deger: $val", style: TextStyle(fontSize: 9, color: theme.colorScheme.primary.withValues(alpha: 0.7), fontWeight: FontWeight.normal)); }), ], ), ); }, ); })), actions: [TextButton(onPressed: () => Get.back(), child: Text("close".tr.toUpperCase(), style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)))]),);
  }

  void _showSceneValueEditDialog(int sceneId, int initialValue) {
    final theme = Get.theme;
    RxInt tempVal = initialValue.obs;
    Get.dialog(AlertDialog(backgroundColor: theme.scaffoldBackgroundColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: Text("${'scenarios'.tr} #$sceneId", style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center), content: Column(mainAxisSize: MainAxisSize.min, children: [Obx(() => Text("%${((tempVal.value / 254) * 100).toInt()}", style: TextStyle(color: theme.colorScheme.primary, fontSize: 24, fontWeight: FontWeight.bold))), const SizedBox(height: 20), Obx(() => Slider(value: tempVal.value.toDouble().clamp(1, 254), min: 1, max: 254, onChanged: (v) => tempVal.value = v.toInt())), ]), actions: [TextButton(onPressed: () { _sendScenarioValueDelete(sceneId); Get.back(); }, child: Text("sil".tr.toUpperCase(), style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold))), TextButton(onPressed: () { _sendScenarioValueUpdate(sceneId, tempVal.value); Get.back(); }, child: Text("kayit".tr.toUpperCase(), style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold))), TextButton(onPressed: () => Get.back(), child: Text("close".tr.toUpperCase(), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))), ], ), );
  }

  void _showRelayDetailsPopup() {
    final theme = Get.theme;
    _sendDaliGetConfigCommand("get_detail");
    Get.dialog(AlertDialog(backgroundColor: theme.scaffoldBackgroundColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), content: SizedBox(width: 350, child: Column(mainAxisSize: MainAxisSize.min, children: [_buildConfigSlider(label: "minimum".tr, value: minLevel, minRx: physicalMin, onRefresh: () => _sendDaliGetConfigCommand("get_min"), onApply: () => _sendDaliConfigCommand("set_min", minLevel.value)), _buildConfigSlider(label: "maximum".tr, value: maxLevel, onRefresh: () => _sendDaliGetConfigCommand("get_max"), onApply: () => _sendDaliConfigCommand("set_max", maxLevel.value)), _buildConfigSlider(label: "error_level".tr, value: errorLevel, onRefresh: () => _sendDaliGetConfigCommand("get_fail"), onApply: () => _sendDaliConfigCommand("set_fail", errorLevel.value)), _buildConfigSlider(label: "power_on_level".tr, value: powerOnLevel, onRefresh: () => _sendDaliGetConfigCommand("get_pwr"), onApply: () => _sendDaliConfigCommand("set_pwr", powerOnLevel.value)), const SizedBox(height: 15), Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [ElevatedButton.icon(onPressed: () => _sendDaliGetConfigCommand("get_detail"), icon: const Icon(Icons.refresh, size: 18), label: Text("full_refresh".tr, style: const TextStyle(fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.surface, foregroundColor: theme.colorScheme.primary, elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))), ElevatedButton.icon(onPressed: () => _showFadeSettingsPopup(), icon: const Icon(Icons.speed, size: 18), label: Text("fade".tr, style: const TextStyle(fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.surface, foregroundColor: theme.colorScheme.primary, elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))), ], ), ], ), ), actions: [TextButton(onPressed: () => Get.back(), child: Text("close".tr.toUpperCase(), style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)))], ), );
  }

  void _showFadeSettingsPopup() {
    final theme = Get.theme;
    final List<String> fadeTimeOptions = ["< 0.7 s", "0.7 s", "1.0 s", "1.4 s", "2.0 s", "2.8 s", "4.0 s", "5.7 s", "8.0 s", "11.3 s", "16.0 s", "22.6 s", "32.0 s", "45.3 s", "64.0 s", "90.5 s"];
    final List<String> fadeRateOptions = ["358 steps/s", "253 steps/s", "179 steps/s", "127 steps/s", "89.4 steps/s", "63.3 steps/s", "44.7 steps/s", "31.6 steps/s", "22.4 steps/s", "15.8 steps/s", "11.2 steps/s", "7.9 steps/s", "5.6 steps/s", "4.0 steps/s", "2.8 steps/s"];
    Get.dialog(AlertDialog(backgroundColor: theme.scaffoldBackgroundColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), content: SizedBox(width: 350, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [_buildFadeSectionHeader(title: "fade".tr, onRefresh: () => _sendDaliGetConfigCommand("get_detail"), onSave: () => _sendDaliConfigCommand("set_fade", (fadeTime.value << 4) | (fadeRate.value & 0x0F))), const SizedBox(height: 8), Obx(() => _buildDropdownRow(label: "fade_time".tr, value: fadeTime.value, items: fadeTimeOptions, onChanged: (val) { if (val != null) fadeTime.value = val; })), const SizedBox(height: 12), Obx(() => _buildDropdownRow(label: "fade_rate".tr, value: (fadeRate.value - 1).clamp(0, 14), items: fadeRateOptions, onChanged: (val) { if (val != null) fadeRate.value = val + 1; })), const Divider(height: 32), _buildFadeSectionHeader(title: "extended_fade_settings".tr, onRefresh: () => _sendDaliGetConfigCommand("get_detail"), onSave: () => _sendDaliConfigCommand("set_efade", (extendedFadeTimeMultiplier.value << 4) | (extendedFadeTimeBase.value & 0x0F))), const SizedBox(height: 8), Obx(() => _buildDropdownRow(label: "ext_fade_base".tr, value: extendedFadeTimeBase.value, items: List.generate(16, (i) => i.toString()), onChanged: (val) { if (val != null) extendedFadeTimeBase.value = val; })), const SizedBox(height: 12), Obx(() => _buildDropdownRow(label: "ext_fade_multiplier".tr, value: extendedFadeTimeMultiplier.value, items: ["100ms", "1s", "10s", "60s"], onChanged: (val) { if (val != null) extendedFadeTimeMultiplier.value = val; })), const SizedBox(height: 20), const Divider(), Obx(() => Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(_getFadeSummary(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.primary), textAlign: TextAlign.center))), ], ), ), ), actions: [TextButton(onPressed: () => Get.back(), child: Text("close".tr.toUpperCase(), style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)))], ), );
  }

  String _getFadeSummary() {
    final List<String> standardTimes = ["0", "0.7", "1.0", "1.4", "2.0", "2.8", "4.0", "5.7", "8.0", "11.3", "16.0", "22.6", "32.0", "45.3", "64.0", "90.5"];
    double extMult = [0.1, 1.0, 10.0, 60.0][extendedFadeTimeMultiplier.value.clamp(0, 3)];
    double extTotal = extendedFadeTimeBase.value * extMult;
    String text = "Standard: ${standardTimes[fadeTime.value.clamp(0, 15)]} s";
    if (extTotal > 0) text += "\nExtended: ${extTotal.toStringAsFixed(1)} s";
    return text;
  }

  Widget _buildFadeSectionHeader({required String title, required VoidCallback onRefresh, required VoidCallback onSave}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)), Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: onRefresh, visualDensity: VisualDensity.compact, color: Get.theme.colorScheme.primary.withValues(alpha: 0.7)), IconButton(icon: const Icon(Icons.save, size: 20), onPressed: onSave, visualDensity: VisualDensity.compact, color: Get.theme.colorScheme.primary), ], ), ], );
  }

  Widget _buildDropdownRow({required String label, required int value, required List<String> items, required ValueChanged<int?> onChanged}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)), const SizedBox(height: 4), Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Get.theme.colorScheme.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: Get.theme.colorScheme.primary.withValues(alpha: 0.3))), child: DropdownButtonHideUnderline(child: DropdownButton<int>(value: value.clamp(0, items.length - 1), isExpanded: true, items: List.generate(items.length, (index) => DropdownMenuItem(value: index, child: Text(items[index], style: const TextStyle(fontSize: 14)))), onChanged: onChanged, ), ), ), ], );
  }

  Widget _buildConfigSlider({required String label, required RxInt value, required VoidCallback onApply, required VoidCallback onRefresh, RxInt? minRx}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.only(left: 8.0, top: 8.0), child: Row(children: [Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), const SizedBox(width: 8), Obx(() => Text("(${value.value})", style: TextStyle(fontSize: 11, color: Get.theme.colorScheme.primary.withValues(alpha: 0.7)))), ], ), ), Row(children: [Expanded(child: Obx(() { double minVal = (minRx?.value.toDouble() ?? 0.0).clamp(0.0, 254.0); return Slider(value: value.value.toDouble().clamp(minVal, 254), min: minVal, max: 254, onChanged: (v) => value.value = v.toInt(), ); })), IconButton(icon: const Icon(Icons.refresh), color: Get.theme.colorScheme.primary.withValues(alpha: 0.6), onPressed: onRefresh), IconButton(icon: const Icon(Icons.check_circle_outline), color: Get.theme.colorScheme.primary, onPressed: onApply), ], ), const Divider(), ], );
  }

  void _showDetailDialog(BuildContext context) {
    final theme = Theme.of(context);
    final userManager = Get.find<UserManagementService>();
    RxInt tempLevel = level.value.obs;
    final worker = ever(level, (int val) => tempLevel.value = val);
    final double dialogWidth = (scrWidth.value * 0.7).clamp(340.0, 600.0);
    final double iconScale = (dialogWidth / 350).clamp(1.0, 1.6);
    Get.dialog(SizedBox(width: dialogWidth, child: AlertDialog(backgroundColor: theme.scaffoldBackgroundColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0), title: Column(children: [Row(children: [Container(width: 32, height: 32, alignment: Alignment.center, decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle, border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3))), child: Text(id.toString(), style: TextStyle(color: theme.colorScheme.primary, fontSize: 13, fontWeight: FontWeight.bold), ), ), const SizedBox(width: 12), Expanded(child: Obx(() => Text(name ?? 'lamp'.tr, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)))), ], ), const SizedBox(height: 15), SizedBox(width: dialogWidth - 40, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_buildTopBarIconBtn(Icons.edit_note, 'rename'.tr, () => _showRenameDialog(context), scale: iconScale), _buildTopBarIconBtn(Icons.meeting_room_outlined, 'change_room'.tr, () => _showRoomSelectionDialog(context), scale: iconScale), _buildTopBarIconBtn(Icons.visibility_off_outlined, 'gizle'.tr, () => _hideDevice(context), scale: iconScale), _buildTopBarIconBtn(Icons.settings_remote, 'get_switches'.tr, () => _showSwitchSelectionDialog(), scale: iconScale), ], )), const Divider(), ], ), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [Padding(padding: const EdgeInsets.only(bottom: 15), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Obx(() { final room = userManager.activeRooms.firstWhereOrNull((r) => r.id == roomId); return _buildInfoChip(Icons.meeting_room, room?.name ?? 'unassigned_room'.tr, theme); }), const SizedBox(width: 10), Obx(() { final sw = userManager.activeSwitches.firstWhereOrNull((s) => s.id == logicButtonId); return _buildInfoChip(Icons.settings_remote, sw?.name ?? 'all_switches'.tr, theme); })], ), ), Obx(() { final bool isOn = tempLevel.value > 0; return InkWell(onTap: () => _changeIcon(context), borderRadius: BorderRadius.circular(40), child: Icon(_getIconData(ico), size: 60, color: activeColor.withValues(alpha: isOn ? 1.0 : 0.2), ), ); }), const SizedBox(height: 20), Obx(() => Column(children: [Text("%${((tempLevel.value / 254) * 100).toInt()}", style: TextStyle(color: theme.colorScheme.primary, fontSize: 20, fontWeight: FontWeight.bold)), Slider(value: tempLevel.value.toDouble().clamp(0, 254), min: 0, max: 254, onChanged: (v) => tempLevel.value = v.toInt(), onChangeEnd: (v) => _sendCommand(v.toInt())), ], )), const SizedBox(height: 10), Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [_buildActionBtn(Icons.power_settings_new, 'open'.tr, () => _sendOpenCommand(), color: Colors.green), _buildActionBtn(Icons.power_settings_new, 'close'.tr, () => _sendOffCommand(), color: Colors.red), _buildActionBtn(Icons.vertical_align_top, 'maximum'.tr, () => _sendMaxCommand()), _buildActionBtn(Icons.vertical_align_bottom, 'minimum'.tr, () => _sendMinCommand()), _buildActionBtn(Icons.fingerprint, 'identify'.tr, () => _sendIdentifyCommand()), ], ), ], ), ), actionsPadding: EdgeInsets.zero, actions: [Column(mainAxisSize: MainAxisSize.min, children: [const Divider(height: 1), Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: SizedBox(width: dialogWidth, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_buildBottomIconWithLabel(Icons.refresh, 'get_level'.tr, () => _sendGetLevelCommand(), scale: iconScale), _buildBottomIconWithLabel(Icons.info_outline, 'status'.tr, () { _showStatusDialog(); _sendQStatusCommand(); }, scale: iconScale), _buildBottomIconWithLabel(Icons.list_alt, 'details'.tr, (channel == 10 || channel == 11) ? null : () => _showRelayDetailsPopup(), scale: iconScale), _buildBottomIconWithLabel(Icons.groups, 'groups'.tr, (channel == 10 || channel == 11) ? null : () { _showGroupsDialog(); _sendGetGroupsCommand(); }, scale: iconScale), _buildBottomIconWithLabel(Icons.auto_awesome, 'scenarios'.tr, (channel == 10 || channel == 11) ? null : () => _showScenariosDialog(), scale: iconScale), ], )), ), const Divider(height: 1), TextButton(onPressed: () => Get.back(), child: Text("close".tr.toUpperCase(), style: TextStyle(color: theme.colorScheme.primary)), ), const SizedBox(height: 4), ], ), ], ), )).then((_) => worker.dispose());
  }

  Widget _buildInfoChip(IconData icon, String label, ThemeData theme) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)), ), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: theme.colorScheme.primary.withValues(alpha: 0.6)), const SizedBox(width: 4), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white, ), ), ], ), );
  }

  Widget _buildTopBarIconBtn(IconData icon, String label, VoidCallback onTap, {double scale = 1.0}) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: Padding(padding: EdgeInsets.all(4.0 * scale), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 23 * scale, color: Get.theme.colorScheme.onSurface.withValues(alpha: 0.8)), SizedBox(height: 4 * scale), Text(label, style: TextStyle(fontSize: 10 * scale, color: Get.theme.colorScheme.onSurface.withValues(alpha: 0.6))), ], ), ), );
  }

  Widget _buildBottomIconWithLabel(IconData icon, String label, VoidCallback? onTap, {double scale = 1.0}) {
    final bool isEnabled = onTap != null;
    return InkWell(onTap: onTap, child: Opacity(opacity: isEnabled ? 1.0 : 0.3, child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 25 * scale, color: Get.theme.colorScheme.onSurface.withValues(alpha: 0.7)), SizedBox(height: 4 * scale), Text(label, style: TextStyle(fontSize: 10 * scale, color: Get.theme.colorScheme.onSurface.withValues(alpha: 0.7))), ], ), ), );
  }

  // Aksiyon butonları: dialogWidth büyüse de sabit kalır.
  Widget _buildActionBtn(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Get.theme.colorScheme.surface, foregroundColor: color ?? Get.theme.colorScheme.primary, elevation: 1, padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10), minimumSize: const Size(114, 0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)), ), ), onPressed: onTap, child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 26), const SizedBox(height: 5), Text(label, style: const TextStyle(fontSize: 14)), ], ), );
  }

  void _hideDevice(BuildContext context) {
    Get.defaultDialog(title: 'gizle'.tr, middleText: 'device_hide_confirm'.tr, textConfirm: 'yes'.tr, textCancel: 'no'.tr, confirmTextColor: Colors.white, onConfirm: () { Get.find<UserManagementService>().updateDeviceIcon(id, channel, 11); Get.back(); Get.back(); }, );
  }

  void _changeIcon(BuildContext context) {
    final theme = Theme.of(context);
    Get.defaultDialog(title: 'select_icon'.tr, backgroundColor: theme.scaffoldBackgroundColor, titleStyle: TextStyle(color: theme.colorScheme.onSurface), content: SizedBox(width: 300, child: Wrap(spacing: 15, runSpacing: 15, alignment: WrapAlignment.center, children: List.generate(lampIcons.length, (index) { final bool isSelected = ico == index; return InkWell(onTap: () { Get.find<UserManagementService>().updateDeviceIcon(id, channel, index); Get.back(); Get.back(); _showDetailDialog(context); }, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: Border.all(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.1)), ), child: Icon(lampIcons[index], color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface, size: 30), ), ); }), ), ), );
  }

  void _showRenameDialog(BuildContext context) {
    final theme = Theme.of(context);
    final TextEditingController nameController = TextEditingController(text: name);
    Get.defaultDialog(backgroundColor: theme.scaffoldBackgroundColor, title: 'rename'.tr, titleStyle: TextStyle(color: theme.colorScheme.onSurface), content: Padding(padding: const EdgeInsets.symmetric(horizontal: 15), child: TextField(controller: nameController, autofocus: true, style: TextStyle(color: theme.colorScheme.onSurface), decoration: InputDecoration(hintText: 'name_hint'.tr, hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3))), ), ), ), confirm: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary), onPressed: () { if (nameController.text.isNotEmpty) { final newName = nameController.text; this.name = newName; Get.find<UserManagementService>().updateDeviceName(id, channel, newName); _sendSaveDeviceToBox(); Get.back(); Get.back(); _showDetailDialog(context); } }, child: Text('save'.tr, style: const TextStyle(color: Colors.white)), ), cancel: OutlinedButton(onPressed: () => Get.back(), child: Text('cancel'.tr, style: TextStyle(color: theme.colorScheme.primary)), ), );
  }

  void _showRoomSelectionDialog(BuildContext context) {
    final theme = Theme.of(context);
    final userManager = Get.find<UserManagementService>();
    Get.bottomSheet(Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), ), child: Column(mainAxisSize: MainAxisSize.min, children: [Text('rooms'.tr, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 15), Flexible(child: ListView.builder(shrinkWrap: true, itemCount: userManager.activeRooms.length, itemBuilder: (context, index) { final room = userManager.activeRooms[index]; return ListTile(leading: Icon(Icons.meeting_room_outlined, color: theme.colorScheme.primary), title: Text(room.name, style: TextStyle(color: theme.colorScheme.onSurface)), onTap: () { this.roomId = room.id; userManager.updateDeviceRoom(id, channel, room.id); _sendSaveDeviceToBox(); Get.back(); Get.back(); _showDetailDialog(context); }, ); }, ), ), ], ), ), );
  }

  void _showSwitchSelectionDialog() {
    final theme = Get.theme;
    final userManager = Get.find<UserManagementService>();
    final List<SwitchInfo> availableSwitches = userManager.activeSwitches.where((s) => s.type == 0).toList();
    Get.bottomSheet(Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), ), child: Column(mainAxisSize: MainAxisSize.min, children: [Text('get_switches'.tr, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 15), if (availableSwitches.isEmpty) Padding(padding: const EdgeInsets.all(20.0), child: Text('no_device_found'.tr), ) else Flexible(child: ListView.builder(shrinkWrap: true, itemCount: availableSwitches.length, itemBuilder: (context, index) { final sw = availableSwitches[index]; final bool isSelected = logicButtonId == sw.id; return ListTile(leading: Icon(Icons.settings_remote, color: isSelected ? theme.colorScheme.primary : Colors.grey), title: Text(sw.name, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)), trailing: isSelected ? Icon(Icons.check_circle, color: theme.colorScheme.primary) : null, onTap: () { _updateDeviceLogicSwitch(sw.id); _sendSaveDeviceToBox(); Get.back(); Get.back(); _showDetailDialog(Get.context!); }, ); }, ), ), ListTile(leading: const Icon(Icons.link_off, color: Colors.red), title: Text('delete_switch'.tr, style: const TextStyle(color: Colors.red)), onTap: () { _updateDeviceLogicSwitch(255); _sendSaveDeviceToBox(); Get.back(); Get.back(); _showDetailDialog(Get.context!); }, ), ], ), ), );
  }

  void _updateDeviceLogicSwitch(int switchId) {
    final userManager = Get.find<UserManagementService>();
    final user = userManager.activeUser.value;
    if (user == null) return;
    logicButtonId = switchId;
    final index = user.deviceList.indexWhere((d) => d.id == id && d.channel == channel);
    if (index != -1) {
      user.deviceList[index] = this; 
      user.devices = jsonEncode(user.deviceList.map((d) => d.toMap()).toList());
      userManager.saveOrUpdateUser(user);
      userManager.activeDevices.assignAll(user.deviceList);
      userManager.activeDevices.refresh();
      debugPrint("--- [RELAY LAMP] Cihaz Anahtar Bağlantısı Güncellendi: Adres $id, Switch: $switchId ---");
    }
  }

  Color _getLampColor(String? deviceName, ThemeData theme) {
    if (deviceName == null) return Colors.orangeAccent;
    final lowerName = deviceName.toLowerCase();

    if (lowerName.contains('yeşil') || lowerName.contains('green')) {
      return Colors.green;
    } else if (lowerName.contains('kırmızı') || lowerName.contains('kirmizi') || lowerName.contains('red')) {
      return Colors.red;
    } else if (lowerName.contains('mavi') || lowerName.contains('blue')) {
      return Colors.blue;
    } else if (lowerName.contains('beyaz') || lowerName.contains('white')) {
      return Colors.white;
    } else if (lowerName.contains('rgb')) {
      return Colors.purpleAccent;
    }

    return Colors.orangeAccent;
  }

  @override
  Widget buildWidget() {
    final theme = Get.theme;
    return Obx(() {
      final bool isOn = level.value > 0;
      return DeviceCardBase(
        name: name ?? 'lamp'.tr,
        id: id,
        roomId: roomId,
        isOn: isOn,
        isBlocked: _isInteractionBlocked.value,
        isRefreshing: _isRefreshingUI.value,
        onTap: () {
          if (isOn) {
            _sendOffCommand();
          } else {
            if (!_isStatusFetched) {
              _sendGetLevelCommand();
            } else {
              _sendActionCommand();
            }
          }
        },
        onLongPress: () => _showDetailDialog(Get.context!),
        icon: Icon(
          _getIconData(ico),
          color: _getLampColor(name, theme).withValues(alpha: isOn ? 1.0 : 0.2),
          size: 70,
        ),
      );
    });
  }
}
