import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../user/userManagementService.dart';
import '../../user/appUser.dart';
import '../../comminication/dataBridgeServis.dart';
import '../../comminication/comminication.dart';
import 'widgets/groupTimingDialog.dart';
import '../../main.dart'; 
import 'alarm.dart'; 
import '../../devices/TermostatButton.dart';
import '../../utils/stt_helper.dart';

class DashboardController extends GetxController {
  final UserManagementService _userManager = Get.find<UserManagementService>();
  final DataBridgeService _dataBridge = Get.find<DataBridgeService>();

  Rxn<AppUser> get activeUser => _userManager.activeUser;
  final selectedIndex = 0.obs;
  final selectedRoomId = Rxn<int>();
  late PageController pageController;

  final selectedGroupIdForScene = Rxn<int>();
  final genericSliderValue = 127.0.obs;
  final selectedScenarioChannel = 9.obs; 

  final selectedGroupChannel = 1.obs;
  final groupPowerValue = 254.0.obs;
  final systemPowerValue = 254.0.obs;

  final isRefreshing = false.obs;
  final refreshCount = 0.obs;
  StreamSubscription? _refreshSubscription;
  Timer? _refreshTimeoutTimer;

  final activeMode = 0.obs; 
  final alarmState = 2.obs; 
  final isIrrigationRunning = false.obs;
  StreamSubscription? _dataSubscription;

  // Sesli Komut Değişkenleri
  final isListening = false.obs;
  final isVoicePreparing = false.obs;
  final lastWords = "".obs;
  
  // FAB Pozisyonu (Ekranın sağ alt köşesi varsayılan)
  final fabPosition = Offset(Get.width - 90, Get.height - 180).obs;

  // Alarm popup'ının mükerrer açılmasını engellemek için bayrak
  bool _isAlarmDialogOpen = false;

  RxBool get isAlarmActive => (alarmState.value == 0).obs;

  @override
  void onInit() {
    super.onInit();
    int initialPage = 0;
    if (_userManager.activeRooms.isNotEmpty) {
      selectedRoomId.value = _userManager.activeRooms.first.id;
      initialPage = 1;
    }
    pageController = PageController(initialPage: initialPage);
    _listenRefreshData();
    _listenData();
    getSystemMode();
  }

  @override
  void onClose() {
    pageController.dispose();
    _refreshSubscription?.cancel();
    _refreshTimeoutTimer?.cancel();
    _dataSubscription?.cancel();
    super.onClose();
  }

  // --- Sesli Komut Mantığı ---

  Future<void> toggleVoiceCommand() async {
    if (isListening.value || isVoicePreparing.value) {
      await SttHelper.stopListening();
      isVoicePreparing.value = false;
      isListening.value = false;
    } else {
      isVoicePreparing.value = true;
      lastWords.value = "Başlatılıyor...";

      await SttHelper.startListening(
        onListeningStarted: () {
          isVoicePreparing.value = false;
          isListening.value = true;
          lastWords.value = "Dinleniyor...";
        },
        onResult: (words) {
          lastWords.value = words;
          _sendVoiceCommand(words);
        },
        onDone: () {
          isVoicePreparing.value = false;
          isListening.value = false;
        },
      );
    }
  }

  String IngilizceyeCevir(String metin) {
    if (metin.isEmpty) return metin;

    const turkceKarakterler = 'çğıişöüÇĞİİŞÖÜ';
    const ingilizceKarakterler = 'cgiisoucgiisou';

    // Karakter eşleştirmelerini harita (map) haline getiriyoruz
    final harita = Map<String, String>.fromIterables(
      turkceKarakterler.split(''),
      ingilizceKarakterler.split(''),
    );

    // Metindeki her karakteri kontrol edip değiştiriyoruz
    return metin.split('').map((harf) => harita[harf] ?? harf).join('').toLowerCase();
  }

  void _sendVoiceCommand(String text) {
    if (text.isEmpty || text == "Dinleniyor...") return;

    final user = _userManager.activeUser.value;

    _sendToOutbox({
      "com": "voice",
      "txt": text,
      "eng": IngilizceyeCevir(text),
      "user": user?.name ?? "Unknown"
    });
  }

  void _listenRefreshData() {
    _refreshSubscription = Get.find<DataBridgeService>().dataStream.listen((data) {
      final payload = data['full_payload'];
      if (payload is Map) {
        final String? com = payload['com'];
        if (com == 'refresh' || com == 'search') {
          final int count = int.tryParse(payload['count']?.toString() ?? '0') ?? 0;
          refreshCount.value = count;
          if (count >= 255) _stopRefresh();
        }
      }
    });
  }

  void _listenData() {
    _dataSubscription = Get.find<DataBridgeService>().dataStream.listen((data) {
      final payload = data['full_payload'];
      if (payload is Map) {
        final String? com = payload['com'];

        if (com == 'get_mode') {
          if (payload.containsKey('mode')) {
            final int? mode = int.tryParse(payload['mode']?.toString() ?? '');
            if (mode != null) activeMode.value = mode;
          }
          if (payload.containsKey('alarm')) {
            final int? alarm = int.tryParse(payload['alarm']?.toString() ?? '');
            if (alarm != null) {
              debugPrint("--- [DASHBOARD] Alarm Durumu Güncellendi (get_mode): $alarm ---");
              alarmState.value = alarm;
            }
          }
        }
        else if (com == 'set_alarm') {
          if (payload.containsKey('state')) {
            final int? state = int.tryParse(payload['state']?.toString() ?? '');
            if (state != null) {
              debugPrint("--- [DASHBOARD] Alarm Durumu Güncellendi (set_alarm): $state ---");
              alarmState.value = state;
            }
          }
        }
        else if (com == 'alarm') {
          final int? status = int.tryParse(payload['status']?.toString() ?? '');
          final String txt = payload['txt']?.toString() ?? 'ALARM';
          if (status == 1) {
            _showEmergencyAlarm(txt);
          }
        }
        else if (com == 'get_irrigation') {
          final int? running = int.tryParse(payload['running']?.toString() ?? '');
          if (running != null) {
            isIrrigationRunning.value = running == 1;
          }
        }
      }
    });
  }

  void _showEmergencyAlarm(String message) {
    if (_isAlarmDialogOpen || Get.isDialogOpen == true) return;

    _isAlarmDialogOpen = true;
    Get.dialog(
      AlarmDialog(message: message),
      barrierDismissible: false,
    ).then((_) {
      _isAlarmDialogOpen = false;
    });
  }

  void getSystemMode() {
    _sendToOutbox({"com": "get_mode"});
  }

  void getIrrigationStatus() {
    _sendToOutbox({"com": "get_irrigation"});
  }

  void setSystemMode(int mode, {int? alarm}) {
    final Map<String, dynamic> msg = {"com": "set_mode", "mode": mode};
    if (alarm != null) {
      msg["alarm"] = alarm;
    }
    _sendToOutbox(msg);
    activeMode.value = mode;
  }

  void toggleAlarm() {
    int currentState = alarmState.value;
    int nextSendState;
    
    if (currentState == 0) { // ON
      nextSendState = 1;
    } else if (currentState == 1) { // PENDING
      nextSendState = 0;
    } else { // OFF (2)
      nextSendState = 0;
    }

    _sendToOutbox({
      "com": "set_alarm",
      "state": nextSendState,
    });
  }

  void dismissAllAlarms() {
    _sendToOutbox({
      "com": "alarm",
      "status": 9,
    });
  }

  void sendRefreshCommand() {
    if (isRefreshing.value) return;
    isRefreshing.value = true;
    refreshCount.value = 0;
    _refreshTimeoutTimer?.cancel();
    _refreshTimeoutTimer = Timer(const Duration(minutes: 3), () {
      if (isRefreshing.value) _stopRefresh();
    });
    _sendToOutbox({"com": "refresh"});
  }

  void _stopRefresh() {
    isRefreshing.value = false;
    refreshCount.value = 0;
    _refreshTimeoutTimer?.cancel();
  }

  void changeIndex(int index) => selectedIndex.value = index;

  void setRoomFilter(int? roomId, {bool updatePage = true}) {
    selectedRoomId.value = roomId;
    if (updatePage && pageController.hasClients) {
      int targetPage = (roomId == null) ? 0 : _userManager.activeRooms.indexWhere((r) => r.id == roomId) + 1;
      pageController.animateToPage(targetPage, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void onPageChanged(int index) {
    if (index == 0) {
      selectedRoomId.value = null;
    } else if (index - 1 < _userManager.activeRooms.length) {
      selectedRoomId.value = _userManager.activeRooms[index - 1].id;
    }
    _refreshThermostatsInCurrentRoom();
  }

  void _refreshThermostatsInCurrentRoom() {
    final roomId = selectedRoomId.value;
    final thermostats = _userManager.activeLogicDevices
        .whereType<ThermostatDevice>()
        .where((t) => roomId == null || t.roomId == roomId);

    for (var t in thermostats) {
      _sendToOutbox({
        "com": "get_temp",
        "adres": t.sensorId,
        "ins": t.sensorInstance,
        "kanal": t.channel
      });
    }
  }

  String get currentRoomName => selectedRoomId.value == null ? 'all_rooms'.tr : (_userManager.activeRooms.firstWhereOrNull((r) => r.id == selectedRoomId.value)?.name ?? 'all_rooms'.tr);

  void logout() => _userManager.activeUser.value = null;

  // --- Grup Aksiyonları ---

  void groupOn(int groupId, {int? power, int? channel}) {
    _sendToOutbox({
      "com": "arc_power",
      "adres": groupId,
      "gurup": 1,
      "power": power ?? 254,
      "kanal": channel ?? 1,
    });
  }

  void groupOff(int groupId, {int? channel}) {
    _sendToOutbox({
      "com": "off",
      "adres": groupId,
      "gurup": 1,
      "kanal": channel ?? 1,
    });
  }

  void getGroupTiming(int groupId) {
    _sendToOutbox({
      "com": "get_grp_time",
      "adres": groupId,
    });
  }

  void saveGroupTiming(int groupId, ZamanT time1, ZamanT time2) {
    _sendToOutbox({
      "com": "set_grp_time",
      "adres": groupId,
      "time1": time1.toJson(),
      "time2": time2.toJson(),
    });
  }

  void renameGroup(int groupId, String name) {
    _sendToOutbox({
      "com": "grpname",
      "grpid": groupId,
      "name": name,
    });
  }

  // --- Senaryo Aksiyonları ---

  void allLightsOff(int sceneId, {int? channel}) {
    _sendToOutbox({
      "com": "off",
      "adres": 255, 
      "gurup": 0,
      "kanal": channel ?? 9,
    });
  }

  void applyToAllLights(int sceneId, {int? channel}) {
    _sendToOutbox({
      "com": "go_scene",
      "adres": 255, 
      "gurup": 0, 
      "scene": sceneId,
      "kanal": channel ?? 9,
    });
  }

  void applyToGroup(int sceneId, int groupId, {int? channel}) {
    _sendToOutbox({
      "com": "go_scene",
      "adres": groupId,
      "gurup": 1,
      "scene": sceneId,
      "kanal": channel ?? 9,
    });
  }

  void getScenarioTiming(int sceneId) {
    _sendToOutbox({
      "com": "get_scn_time",
      "adres": sceneId,
    });
  }

  void saveScenarioTiming(int sceneId, ZamanT time1, ZamanT time2) {
    _sendToOutbox({
      "com": "set_scn_time",
      "adres": sceneId,
      "time1": time1.toJson(),
      "time2": time2.toJson(),
    });
  }

  void renameScene(int sceneId, String name) {
    _sendToOutbox({
      "com": "scnname",
      "sceneid": sceneId,
      "name": name,
    });
  }

  void setSceneLevel(int sceneId, int level) {
    final groupId = selectedGroupIdForScene.value ?? 255;
    _sendToOutbox({
      "com": "set_scene",
      "adres": 0,
      "gurup": groupId,
      "scene": sceneId,
      "value": level,
      "kanal": 0,
    });
  }

  void selectGroupForScene(int? groupId) {
    selectedGroupIdForScene.value = groupId;
  }

  void setGenericSlider(double value) {
    genericSliderValue.value = value;
  }

  // --- Sistem Geneli Güç Kontrolü ---
  
  void systemOpen({int? power}) {
    _sendToOutbox({
      "com": "arc_power",
      "adres": 255,
      "gurup": 0,
      "power": power ?? systemPowerValue.value.toInt(),
      "kanal": 9,
    });
  }

  void systemClose() {
    _sendToOutbox({
      "com": "off",
      "adres": 255,
      "gurup": 0,
      "kanal": 9,
    });
  }

  List<GrpInfo> get groups => _userManager.activeGroups;

  void _sendToOutbox(Map<String, dynamic> msg) {
    final bool forceMqtt = !isTablet.value;
    final user = _userManager.activeUser.value;
    final String? boxIp = user?.deviceIp;
    final receiver = (boxIp != null && boxIp.isNotEmpty) ? MessageOwner(transmission: TransmissionType.udp, ip: boxIp, port: 53250) : null;
    try {
      Get.find<DataBridgeService>().send(msg, receiver: receiver, forceMqtt: forceMqtt);
    } catch (e) {
      debugPrint("DataBridgeService hatası: $e");
    }
  }
}
