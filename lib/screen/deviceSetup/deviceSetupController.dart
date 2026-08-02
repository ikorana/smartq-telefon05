import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

import '../../comminication/comminication.dart';
import '../../comminication/dataBridgeServis.dart';
import '../../devices/base.dart';
import '../../user/appUser.dart';
import '../../user/userManagementService.dart';

enum SetupCategory { none, room, intro, device, system }

class DeviceSetupController extends GetxController {
  final UserManagementService _userManager = Get.find<UserManagementService>();
  final DataBridgeService _dataBridge = Get.find<DataBridgeService>();
  
  final RxList<String> terminalLogs = <String>[].obs;
  StreamSubscription? _logSubscription;
  StreamSubscription? _dataSubscription;

  RxList<RoomInfo> get rooms => _userManager.activeRooms;
  
  List<BaseDevice> get sortedActiveDevices {
    final list = _userManager.activeDevices.toList();
    list.sort((a, b) => a.id.compareTo(b.id));
    return list;
  }

  // Aktif kullanıcının admin durumunu döndürür
  bool get isAdmin => _userManager.activeUser.value?.isAdmin ?? false;
  AppUser? get currentUser => _userManager.activeUser.value;
  
  final Rx<SetupCategory> selectedCategory = SetupCategory.none.obs;

  // Buton yükleme durumları
  final RxBool isAllOnLoading = false.obs;
  final RxBool isAllOffLoading = false.obs;
  final RxMap<String, bool> buttonLoadingStates = <String, bool>{}.obs;

  // Seçili cihaz takibi (Genişletilmiş kart için)
  final RxString selectedDeviceKey = "".obs;

  // Auto Setup Durumu
  final RxBool isAutoSetupRunning = false.obs;
  int _autoSetupChannelCounter = 0;

  @override
  void onInit() {
    super.onInit();
    _startLogListening();
    _startDataListening();
  }

  void toggleDeviceSelection(int id, int channel) {
    final key = "${id}_$channel";
    if (selectedDeviceKey.value == key) {
      selectedDeviceKey.value = ""; 
    } else {
      selectedDeviceKey.value = key; 
    }
  }

  void changeCategory(SetupCategory category) {
    selectedCategory.value = category;
  }

  void _startLogListening() {
    _logSubscription = _dataBridge.logStream.listen((msg) {
      _addLog(msg);
    });
  }

  void _startDataListening() {
    _dataSubscription = _dataBridge.dataStream.listen((data) {
      if (!isAutoSetupRunning.value) return;

      final payload = data['full_payload'];
      if (payload is Map) {
        final com = payload['com'];
        
        if (com == 'room_intro') {
          _addLog("SİSTEM: Oda bilgileri alındı, anahtarlar isteniyor...");
          getSwitches();
        } else if (com == 'switch_intro') {
          _addLog("SİSTEM: Anahtar bilgileri alındı, gruplar isteniyor...");
          groupIntro();
        } else if (com == 'grpintro') {
          _addLog("SİSTEM: Grup bilgileri alındı, senaryolar isteniyor...");
          scenarioIntro();
        } else if (com == 'scnintro') {
          _addLog("SİSTEM: Senaryo bilgileri alındı, kanal bazlı cihaz taraması başlatılıyor...");
          _autoSetupChannelCounter = currentUser?.wifi == 1 ? 0 : 1;
          final total = currentUser?.totalChannels ?? 0;
          if (_autoSetupChannelCounter <= total) {
             _addLog("SİSTEM: Kanal $_autoSetupChannelCounter cihazları isteniyor...");
             fetchDevicesByType(_autoSetupChannelCounter);
          } else {
             sendGeneralCommand({"com": "ins_intro"});
          }
        } else if (com == 'intro') {
          if (_autoSetupChannelCounter >= 0) {
            _autoSetupChannelCounter++;
            final total = currentUser?.totalChannels ?? 0;
            if (_autoSetupChannelCounter <= total) {
               _addLog("SİSTEM: Kanal $_autoSetupChannelCounter cihazları isteniyor...");
               fetchDevicesByType(_autoSetupChannelCounter);
            } else {
               _autoSetupChannelCounter = -1;
               _addLog("SİSTEM: Tüm kanallar tarandı, alt cihazlar isteniyor...");
               sendGeneralCommand({"com": "ins_intro"});
            }
          }
        }
else if (com == 'ins_intro') {
          _addLog("----------------------------------------------");
          _addLog("SİSTEM: Otomatik kurulum başarıyla tamamlandı.");
          isAutoSetupRunning.value = false;
        }
      }
    });
  }

  Future<void> startAutoSetup() async {
    _addLog("SİSTEM: Otomatik kurulum başlatıldı...");
    
    // Önce lokal verileri temizle (onay almadan)
    _userManager.clearLocalDeviceData();
    _addLog("SİSTEM: Mevcut lokal veriler temizlendi.");

    _addLog("--------------------------------------");
    isAutoSetupRunning.value = true;
    _autoSetupChannelCounter = -1;
    sendGetRoom(); 
  }

  Future<void> runDebouncedAction(String key, FutureOr<void> Function() action) async {
    if (buttonLoadingStates[key] == true) return;
    
    buttonLoadingStates[key] = true;
    try {
      await action();
    } catch (e) {
      _addLog("Eylem Hatası: $e");
    } finally {
      await Future.delayed(const Duration(seconds: 2));
      buttonLoadingStates.remove(key);
    }
  }

  // --- ODA YÖNETİMİ ---
  void sendGetRoom() {
    _sendBoxCommand({"com": "room_intro"});
  }

  void addRoom(Map<String, dynamic> command) {
    _sendBoxCommand(command);
  }

  void deleteRoom(int roomId) {
    _sendBoxCommand({"com": "del_oda", "id": roomId});
  }

  void deleteAllRooms() {
    _sendBoxCommand({"com": "del_oda", "id": 99});
  }

  // --- ANAHTAR (SWITCH) YÖNETİMİ ---
  void getSwitches() {
    _sendBoxCommand({"com": "switch_intro"});
  }

  void addSwitch({
    required String name,
    required int type,
    required int sensorId,
    required int sensorInstance,
    required int relayId,
    required int relayChannel,
    int sensorChannel = 0,
  }) {
    _sendBoxCommand({
      "com": "cre_switch",
      "txt": name,
      "tip": type,
      "sid": sensorId,
      "sin": sensorInstance,
      "rid": relayId,
      "rka": relayChannel,
      "senschn": sensorChannel,
    });
  }

  void deleteSwitch(int id) {
    _sendBoxCommand({"com": "del_switch", "id": id});
  }

  void groupIntro() {
    _sendBoxCommand({"com": "grpintro"});
  }
  void scenarioIntro() {
    _sendBoxCommand({"com": "scnintro"});
  }
  void roomIntro() {
    _sendBoxCommand({"com": "intro"});
  }

  void sendGeneralCommand(Map<String, dynamic> command) {
    _sendBoxCommand(command);
  }
  
  // --- CİHAZ & KANAL YÖNETİMİ ---
  void saveDeviceSettings(BaseDevice device) {
    final Map<String, dynamic> data = device.toMap();
    data['com'] = 'save_dev';
    data['id'] = device.id; 
    data['kanal'] = device.channel;

    _sendBoxCommand(data);
    _addLog("SİSTEM: Cihaz ayarları BOX'a gönderildi (${device.name})");
  }

  Future<void> turnAllOn() async {
    if (isAllOnLoading.value) return;
    
    isAllOnLoading.value = true;
    _sendBoxCommand({
      "com": "arc_power",
      "adres": 255,
      "gurup": 0,
      "power": 200,
      "kanal": 9,
    });
    
    await Future.delayed(const Duration(seconds: 2));
    isAllOnLoading.value = false;
  }

  Future<void> turnAllOff() async {
    if (isAllOffLoading.value) return;

    isAllOffLoading.value = true;
    _sendBoxCommand({
      "com": "off",
      "adres": 255,
      "gurup": 0,
      "power": 200,
      "kanal": 9
    });

    await Future.delayed(const Duration(seconds: 2));
    isAllOffLoading.value = false;
  }

  void turnDeviceOn(int id, int channel) {
    _sendBoxCommand({
      "com": "arc_power",
      "adres": id,
      "gurup": 0,
      "power": 200,
      "kanal": channel
    });
  }

  void turnDeviceOff(int id, int channel) {
    _sendBoxCommand({
      "com": "off",
      "adres": id,
      "gurup": 0,
      "power": 200,
      "kanal": channel
    });
  }

  void identifyDevice(int id, int channel) {
    _sendBoxCommand({
      "com": "identfy",
      "adres": id,
      "kanal": channel
    });
  }

  void startAdvancedSearch(int cableType) {
    Get.defaultDialog(
      title: 'search_devices'.tr,
      middleText: 'search_save_confirm'.tr,
      textConfirm: 'yes'.tr,
      textCancel: 'no'.tr,
      confirmTextColor: Colors.white,
      onConfirm: () {
        _sendSearchCommand(cableType, 1);
        Get.back();
      },
      onCancel: () {
        _sendSearchCommand(cableType, 0);
        Get.back();
      },
    );
  }

  void fetchDevicesByType(int type) {
    _sendBoxCommand({
      "com": "intro",
      "type": type
    });
  }

  void _sendSearchCommand(int cable, int kayit) {
    _sendBoxCommand(<String, dynamic>{
      "com": "search",
      "kayit": kayit,
      "cable": cable
    });
  }

  void clearDeviceList(int kanal) {
    _sendBoxCommand({
      "com": "clear_number",
      "id": 255,
      "kanal": kanal
    });
  }

  void clearLocalDevices() {
    _userManager.clearLocalDeviceData();
    _addLog("SİSTEM: Lokal cihaz verileri temizlendi.");
  }

  // --- SİSTEM ARAÇLARI ---
  void getVersion() {
    _sendBoxCommand({"com": "get_version", "type": 2});
  }

  void _sendBoxCommand(Map<String, dynamic> command, {Duration? timeout}) {
    final activeUser = _userManager.activeUser.value;
    final String? deviceIp = activeUser?.deviceIp;
    
    if (deviceIp != null && deviceIp.isNotEmpty) {
      final owner = MessageOwner(
        transmission: TransmissionType.udp, 
        ip: deviceIp,
        port: 53250,
      );
      _dataBridge.send(command, receiver: owner, timeout: timeout);
    } else {
      _addLog("HATA: Aktif kullanıcı IP'si bulunamadı.");
      _dataBridge.send(command, timeout: timeout);
    }
  }

  void _addLog(String msg) {
    terminalLogs.add(msg);
    if (terminalLogs.length > 100) {
      terminalLogs.removeAt(0);
    }
  }

  void clearTerminal() {
    terminalLogs.clear();
  }

  @override
  void onClose() {
    _logSubscription?.cancel();
    _dataSubscription?.cancel();
    super.onClose();
  }
}
