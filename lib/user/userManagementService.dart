import 'dart:convert';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter/foundation.dart';
import 'appUser.dart';
import '../devices/base.dart';

class UserManagementService extends GetxService {
  final GetStorage _storage = GetStorage();
  
  final RxList<AppUser> users = <AppUser>[].obs;
  final Rxn<AppUser> activeUser = Rxn<AppUser>();

  final RxList<RoomInfo> activeRooms = <RoomInfo>[].obs;
  final RxList<BaseDevice> activeDevices = <BaseDevice>[].obs;
  final RxList<GrpInfo> activeGroups = <GrpInfo>[].obs;
  final RxList<ScnInfo> activeScenes = <ScnInfo>[].obs;
  final RxList<SwitchInfo> activeSwitches = <SwitchInfo>[].obs;
  final RxList<BaseDevice> activeLogicDevices = <BaseDevice>[].obs;
  final RxList<InsIntroScn> activeInsIntroList = <InsIntroScn>[].obs;

  final RxString activeLanguage = 'tr'.obs;
  final RxInt activeThemeIndex = 1.obs;
  final RxString lastActiveName = ''.obs;
  
  List<String> get userNames => users.map((u) => u.name).toList();

  @override
  void onInit() {
    super.onInit();
    _loadUsers();
  }

  void _loadUsers() {
    final List<dynamic>? storedUsers = _storage.read<List<dynamic>>('users');
    if (storedUsers != null) {
      users.assignAll(storedUsers.map((json) => AppUser.fromJson(json)).toList());
    }

    // Demo kullanıcısını ekle veya güncelle
    _ensureDemoUser();

    final String? activeUserId = _storage.read<String>('activeUserId');
    if (activeUserId != null) {
      final user = users.firstWhereOrNull((u) => u.id == activeUserId);
      if (user != null) {
        _setActiveUser(user);
      }
    }
  }

  void _ensureDemoUser() {
    const String demoId = "demo_user_01";
    final demoRooms = jsonEncode([
      {"id": 1, "nm": "Salon"},
      {"id": 2, "nm": "Mutfak"},
      {"id": 3, "nm": "Bahçe"},
      {"id": 4, "nm": "Garaj"}
    ]);

    final demoGroups = jsonEncode([
      {"id": 1, "nm": "Tüm Işıklar", "ico": 6},
      {"id": 2, "nm": "Dış Mekan", "ico": 14},
    ]);

    final demoScenes = jsonEncode([
      {"id": 1, "nm": "Sinema Modu", "ico": 15},
      {"id": 2, "nm": "Uyku Modu", "ico": 15},
      {"id": 3, "nm": "Parti Modu", "ico": 12},
    ]);

    final demoDevices = jsonEncode([
      {"gr": 1, "nm": "Salon Avize", "tp": 7, "ex": 0x76, "pr": 1, "vr": 1, "ico": 6, "v": 0},
      {"gr": 2, "nm": "Mutfak Işığı", "tp": 7, "ex": 0x76, "pr": 1, "vr": 2, "ico": 6, "v": 0},
      {"gr": 3, "nm": "Bahçe Sulama", "tp": 7, "ex": 0x79, "pr": 1, "vr": 3, "ico": 0, "v": 0},
      {"gr": 4, "nm": "Ana Vana", "tp": 7, "ex": 0x7D, "pr": 1, "vr": 2, "ico": 0, "v": 0},
      {"gr": 5, "nm": "Garaj Kapısı", "tp": 7, "ex": 0x7F, "pr": 1, "vr": 4, "ico": 0, "v": 0},
      {"gr": 6, "nm": "Dış Kapı", "tp": 7, "ex": 0x7E, "pr": 1, "vr": 3, "ico": 0, "v": 0},
      {"gr": 7, "nm": "Salon Perde", "tp": 7, "ex": 0x77, "pr": 1, "vr": 1, "ico": 0, "v": 0},
      {"gr": 8, "nm": "Mutfak Radyo", "tp": 20, "ex": 0, "pr": 1, "vr": 2, "ico": 0, "v": 0},
    ]);

    final demoUser = AppUser(
      name: "demo",
      id: demoId,
      license: "DEMO_LICENSE",
      deviceIp: "127.0.0.1",
      rooms: demoRooms,
      devices: demoDevices,
      group: demoGroups,
      scene: demoScenes,
      themeIndex: 1,
      language: 'tr',
      ai: 1,
      totalChannels: 1,
      version: "1.0.0-DEMO"
    );

    int index = users.indexWhere((u) => u.id == demoId);
    if (index != -1) {
      users[index] = demoUser;
    } else {
      users.add(demoUser);
    }
  }

  void saveOrUpdateUser(AppUser user) {
    final index = users.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      final existingUser = users[index];
      
      // Kullanıcı editlendiğinde mevcut JSON string verileri koruyoruz.
      // Eğer veriler açıkça boş dizi ("[]") set edilmişse, koruma mantığını (??=) bypass ederiz.
      user.rooms ??= existingUser.rooms;
      user.devices ??= existingUser.devices;
      user.group ??= existingUser.group;
      user.scene ??= existingUser.scene;
      user.switches ??= existingUser.switches;
      user.insIntro ??= existingUser.insIntro;

      // Runtime listelerini koruyoruz
      if (user.roomList.isEmpty && existingUser.roomList.isNotEmpty && user.rooms != "[]") user.roomList = existingUser.roomList;
      if (user.deviceList.isEmpty && existingUser.deviceList.isNotEmpty && user.devices != "[]") user.deviceList = existingUser.deviceList;
      if (user.groupList.isEmpty && existingUser.groupList.isNotEmpty && user.group != "[]") user.groupList = existingUser.groupList;
      if (user.sceneList.isEmpty && existingUser.sceneList.isNotEmpty && user.scene != "[]") user.sceneList = existingUser.sceneList;
      if (user.switchList.isEmpty && existingUser.switchList.isNotEmpty && user.switches != "[]") user.switchList = existingUser.switchList;
      if (user.insIntroList.isEmpty && existingUser.insIntroList.isNotEmpty && user.insIntro != "[]") user.insIntroList = existingUser.insIntroList;
      
      users[index] = user;
    } else {
      users.add(user);
    }
    _saveToDisk();
    
    if (activeUser.value?.id == user.id) {
       _setActiveUser(user);
    }
  }

  void deleteUser(String userId) {
    users.removeWhere((u) => u.id == userId);
    if (activeUser.value?.id == userId) {
      activeUser.value = null;
      _storage.remove('activeUserId');
      activeRooms.clear();
      activeDevices.clear();
      activeGroups.clear();
      activeScenes.clear();
      activeSwitches.clear();
      activeLogicDevices.clear();
      activeInsIntroList.clear();
    }
    _saveToDisk();
  }

  void login(AppUser user) {
    _setActiveUser(user);
    _storage.write('activeUserId', user.id);
  }

  void logout() {
    activeUser.value = null;
    _storage.remove('activeUserId');
    activeRooms.clear();
    activeDevices.clear();
    activeGroups.clear();
    activeScenes.clear();
    activeSwitches.clear();
    activeLogicDevices.clear();
    activeInsIntroList.clear();
  }

  void _setActiveUser(AppUser user) {
    activeUser.value = user;
    activeLanguage.value = user.language;
    activeThemeIndex.value = user.themeIndex;
    lastActiveName.value = user.name;

    print("Aktif Kullanıcı DEGİŞİYOR:  ${user.name} Wifi:${user.wifi}");

    user.channelMenus.clear();
    if (user.totalChannels != null && user.totalChannels! > 0) {
       for (int i = 1; i <= user.totalChannels!; i++) {
         user.channelMenus.add(ChannelMenu(name: 'Kanal $i', channel: i));
       }
    }
    if (user.wifi != null && user.wifi! > 0) {
      user.channelMenus.add(ChannelMenu(name: 'Wifi Kanal', channel: 0));
    }


    if (user.rooms != null) {
      final List<dynamic> roomJson = jsonDecode(user.rooms!);
      activeRooms.assignAll(roomJson.map((j) => RoomInfo.fromJson(j)).toList());
      user.roomList = activeRooms.toList();
    } else {
      activeRooms.clear();
    }

    if (user.devices != null) {
      final List<dynamic> deviceJson = jsonDecode(user.devices!);
      activeDevices.assignAll(deviceJson.map((j) => BaseDevice.createFromMap(j)).toList());
      user.deviceList = activeDevices.toList();
    } else {
      activeDevices.clear();
    }

    if (user.group != null) {
      final List<dynamic> groupJson = jsonDecode(user.group!);
      activeGroups.assignAll(groupJson.map((j) => GrpInfo.fromJson(j)).toList());
      user.groupList = activeGroups.toList();
    } else {
      activeGroups.clear();
    }

    if (user.scene != null) {
      final List<dynamic> sceneJson = jsonDecode(user.scene!);
      activeScenes.assignAll(sceneJson.map((j) => ScnInfo.fromJson(j)).toList());
      user.sceneList = activeScenes.toList();
    } else {
      activeScenes.clear();
    }

    if (user.switches != null) {
      final List<dynamic> switchJson = jsonDecode(user.switches!);
      activeSwitches.assignAll(switchJson.map((j) => SwitchInfo.fromJson(j)).toList());
      user.switchList = activeSwitches.toList();
      
      activeLogicDevices.assignAll(
        activeSwitches.where((s) => s.type == 0 || s.type == 3).map((s) => BaseDevice.createFromMap(s.toJson())).toList()
      );
    } else {
      activeSwitches.clear();
      activeLogicDevices.clear();
    }

    if (user.insIntro != null) {
      final List<dynamic> insIntroJson = jsonDecode(user.insIntro!);
      activeInsIntroList.assignAll(insIntroJson.map((j) => InsIntroScn.fromJson(j)).toList());
      user.insIntroList = activeInsIntroList.toList();
    } else {
      activeInsIntroList.clear();
    }
  }

  void _saveToDisk() {
    _storage.write('users', users.map((u) => u.toJson()).toList());
  }

  AppUser? readUser(String name) {
    return users.firstWhereOrNull((u) => u.name == name);
  }

  void changeActiveUser(String name) {
    final user = readUser(name);
    if (user != null) {
      login(user);

    }
  }

  void updateActiveUserRooms(List<dynamic> rooms) {
    if (activeUser.value == null) return;
    final roomString = jsonEncode(rooms);
    activeUser.value!.rooms = roomString;
    activeRooms.assignAll(rooms.map((j) => RoomInfo.fromJson(j)).toList());
    activeUser.value!.roomList = activeRooms.toList();
    saveOrUpdateUser(activeUser.value!);
  }

  void clearActiveUserRooms() {
    if (activeUser.value == null) return;
    activeUser.value!.rooms = "[]";
    activeRooms.clear();
    activeUser.value!.roomList = [];
    saveOrUpdateUser(activeUser.value!);
  }

  void updateActiveUserGroups(List<dynamic> groups) {
    if (activeUser.value == null) return;
    final groupString = jsonEncode(groups);
    activeUser.value!.group = groupString;
    activeGroups.assignAll(groups.map((j) => GrpInfo.fromJson(j)).toList());
    activeUser.value!.groupList = activeGroups.toList();
    saveOrUpdateUser(activeUser.value!);
  }

  void updateActiveUserScenes(List<dynamic> scenes) {
    if (activeUser.value == null) return;
    final sceneString = jsonEncode(scenes);
    activeUser.value!.scene = sceneString;
    activeScenes.assignAll(scenes.map((j) => ScnInfo.fromJson(j)).toList());
    activeUser.value!.sceneList = activeScenes.toList();
    saveOrUpdateUser(activeUser.value!);
  }

  void updateActiveUserSwitches(List<dynamic> switches) {
    if (activeUser.value == null) return;
    final switchString = jsonEncode(switches);
    activeUser.value!.switches = switchString;
    activeSwitches.assignAll(switches.map((j) => SwitchInfo.fromJson(j)).toList());
    activeUser.value!.switchList = activeSwitches.toList();

    // ÖNEMLİ: activeLogicDevices'i toptan (assignAll ile sıfırdan) yeniden
    // kurmak, termostatların push_temp/get_temp ile canlı güncellenen
    // durumunu (level/setPoint/relayStatus/workType) her switch_intro
    // yenilemesinde sıfırlıyordu — çünkü SwitchInfo canlı sıcaklık/setpoint
    // taşımıyor (sadece statik/oluşturma anı verisi). Bunun yerine: id'si
    // eşleşen MEVCUT cihazı koru (sadece isim/oda gibi statik alanları
    // güncelle), sadece gerçekten yeni olan switch'leri ekle.
    final relevantSwitches = activeSwitches.where((s) => s.type == 0 || s.type == 3);
    final List<BaseDevice> merged = [];
    for (final s in relevantSwitches) {
      final existing = activeLogicDevices.firstWhereOrNull((d) => d.id == s.id);
      if (existing != null) {
        existing.name = s.name;
        existing.roomId = s.room;
        merged.add(existing);
      } else {
        merged.add(BaseDevice.createFromMap(s.toJson()));
      }
    }
    activeLogicDevices.assignAll(merged);

    saveOrUpdateUser(activeUser.value!);
  }

  void updateActiveUserDevices(List<dynamic> gear, {int? channel}) {
    if (activeUser.value == null) return;
    List<BaseDevice> currentDevices = List.from(activeDevices);
    for (var g in gear) {
      final newDev = BaseDevice.createFromMap(g);
      final index = currentDevices.indexWhere((d) => d.id == newDev.id && d.channel == newDev.channel);
      if (index != -1) {
        currentDevices[index] = newDev;
      } else {
        currentDevices.add(newDev);
      }
    }
    activeDevices.assignAll(currentDevices);
    activeUser.value!.devices = jsonEncode(currentDevices.map((d) => d.toMap()).toList());
    activeUser.value!.deviceList = currentDevices;
    saveOrUpdateUser(activeUser.value!);
  }

  void clearDevicesByChannel(int channel) {
    if (activeUser.value == null) return;
    List<BaseDevice> currentDevices = List.from(activeDevices);
    currentDevices.removeWhere((d) => d.channel == channel);
    
    activeDevices.assignAll(currentDevices);
    activeUser.value!.devices = jsonEncode(currentDevices.map((d) => d.toMap()).toList());
    activeUser.value!.deviceList = currentDevices;
    saveOrUpdateUser(activeUser.value!);
    activeDevices.refresh();
  }

  void updateActiveUserInsIntro(List<dynamic> scn) {
    if (activeUser.value == null) return;

    bool hasReset = scn.any((item) => (item['adr'] == 0 || item['adr'] == "0"));
    List<InsIntroScn> newList = hasReset ? [] : List.from(activeInsIntroList);
    
    for (var item in scn) {
      final newItem = InsIntroScn.fromJson(item);
      if (newItem.adr == 0) continue; 
      
      final index = newList.indexWhere((i) => i.adr == newItem.adr && i.iadr == newItem.iadr && i.chn == newItem.chn);
      if (index != -1) {
        newList[index] = newItem;
      } else {
        newList.add(newItem);
      }
    }

    activeInsIntroList.assignAll(newList);
    activeUser.value!.insIntro = jsonEncode(newList.map((i) => i.toJson()).toList());
    activeUser.value!.insIntroList = newList;
    saveOrUpdateUser(activeUser.value!);
  }

  void updateSingleInsIntro(Map<String, dynamic> data) {
    if (activeUser.value == null) return;
    
    final int adr = int.tryParse(data['adr']?.toString() ?? '') ?? 0;
    final int insIdx = int.tryParse(data['ins']?.toString() ?? '') ?? 0;
    final int? kanal = int.tryParse(data['kanal']?.toString() ?? '');

    final index = activeInsIntroList.indexWhere(
      (i) => i.adr == adr && i.iadr == insIdx && (kanal == null || i.chn == kanal),
    );
    if (index != -1) {
      final current = activeInsIntroList[index];
      activeInsIntroList[index] = current.copyWith(
        act: int.tryParse(data['act']?.toString() ?? ''),
        stat: int.tryParse(data['stat']?.toString() ?? ''),
        cm: int.tryParse(data['cmtype']?.toString() ?? ''),
        cmadr: int.tryParse(data['cmadr']?.toString() ?? ''),
        proc: int.tryParse(data['pro']?.toString() ?? ''),
        tset: int.tryParse(data['tset']?.toString() ?? ''),
      );
      
      activeUser.value!.insIntro = jsonEncode(activeInsIntroList.map((i) => i.toJson()).toList());
      activeUser.value!.insIntroList = activeInsIntroList.toList();
      saveOrUpdateUser(activeUser.value!);
      activeInsIntroList.refresh();
    }
  }

  void clearLocalDeviceData() {
    if (activeUser.value == null) return;
    final user = activeUser.value!;
    
    // Clear storage strings first with empty array to bypass restoration logic
    user.devices = "[]";
    user.switches = "[]";
    user.insIntro = "[]";
    
    // Runtime listeleri temizle
    user.deviceList = [];
    user.switchList = [];
    user.insIntroList = [];
    
    // Observable listeleri temizle
    activeDevices.clear();
    activeSwitches.clear();
    activeLogicDevices.clear();
    activeInsIntroList.clear();
    
    saveOrUpdateUser(user);
    
    // Refresh observable lists to update UI
    activeDevices.refresh();
    activeSwitches.refresh();
    activeLogicDevices.refresh();
    activeInsIntroList.refresh();
  }

  void updateDeviceName(int id, int channel, String newName) {
    final device = activeDevices.firstWhereOrNull((d) => d.id == id && d.channel == channel);
    if (device != null) {
      device.name = newName;
      activeUser.value!.devices = jsonEncode(activeDevices.map((d) => d.toMap()).toList());
      saveOrUpdateUser(activeUser.value!);
      activeDevices.refresh();
    }
  }

  void updateDeviceRoom(int id, int channel, int roomId) {
    final device = activeDevices.firstWhereOrNull((d) => d.id == id && d.channel == channel);
    if (device != null) {
      device.roomId = roomId;
      activeUser.value!.devices = jsonEncode(activeDevices.map((d) => d.toMap()).toList());
      saveOrUpdateUser(activeUser.value!);
      activeDevices.refresh();
    }
  }

  void updateDeviceIcon(int id, int channel, int icon) {
    final device = activeDevices.firstWhereOrNull((d) => d.id == id && d.channel == channel);
    if (device != null) {
      device.ico = icon;
      activeUser.value!.devices = jsonEncode(activeDevices.map((d) => d.toMap()).toList());
      saveOrUpdateUser(activeUser.value!);
      activeDevices.refresh();
    }
  }

  void updateSwitchName(int id, String name) {
    final sw = activeSwitches.firstWhereOrNull((s) => s.id == id);
    if (sw != null) {
      final index = activeSwitches.indexOf(sw);
      activeSwitches[index] = SwitchInfo(
        type: sw.type, id: sw.id, name: name, icon: sw.icon, level: sw.level,
        sensorId: sw.sensorId, sensorInstance: sw.sensorInstance, sensorChannel: sw.sensorChannel,
        relayId: sw.relayId, relayChannel: sw.relayChannel, room: sw.room
      );
      activeUser.value!.switches = jsonEncode(activeSwitches.map((s) => s.toJson()).toList());
      saveOrUpdateUser(activeUser.value!);
    }
  }

  void updateSwitchRoom(int id, int roomId) {
    final sw = activeSwitches.firstWhereOrNull((s) => s.id == id);
    if (sw != null) {
      final index = activeSwitches.indexOf(sw);
      activeSwitches[index] = SwitchInfo(
        type: sw.type, id: sw.id, name: sw.name, icon: sw.icon, level: sw.level,
        sensorId: sw.sensorId, sensorInstance: sw.sensorInstance, sensorChannel: sw.sensorChannel,
        relayId: sw.relayId, relayChannel: sw.relayChannel, room: roomId
      );
      activeUser.value!.switches = jsonEncode(activeSwitches.map((s) => s.toJson()).toList());
      saveOrUpdateUser(activeUser.value!);
    }
  }

  void updateGroupIcon(int id, int icon) {
    final group = activeGroups.firstWhereOrNull((g) => g.id == id);
    if (group != null) {
      final index = activeGroups.indexOf(group);
      activeGroups[index] = GrpInfo(id: group.id, name: group.name, icon: icon);
      activeUser.value!.group = jsonEncode(activeGroups.map((g) => g.toJson()).toList());
      saveOrUpdateUser(activeUser.value!);
    }
  }

  void updateGroupName(int id, String name) {
    final group = activeGroups.firstWhereOrNull((g) => g.id == id);
    if (group != null) {
      final index = activeGroups.indexOf(group);
      activeGroups[index] = GrpInfo(id: group.id, name: name, icon: group.icon);
      activeUser.value!.group = jsonEncode(activeGroups.map((g) => g.toJson()).toList());
      saveOrUpdateUser(activeUser.value!);
    }
  }

  void updateSceneIcon(int id, int icon) {
    final scene = activeScenes.firstWhereOrNull((s) => s.id == id);
    if (scene != null) {
      final index = activeScenes.indexOf(scene);
      activeScenes[index] = ScnInfo(id: scene.id, name: scene.name, icon: icon);
      activeUser.value!.scene = jsonEncode(activeScenes.map((s) => s.toJson()).toList());
      saveOrUpdateUser(activeUser.value!);
    }
  }

  void updateSceneName(int id, String name) {
    final scene = activeScenes.firstWhereOrNull((s) => s.id == id);
    if (scene != null) {
      final index = activeScenes.indexOf(scene);
      activeScenes[index] = ScnInfo(id: scene.id, name: name, icon: scene.icon);
      activeUser.value!.scene = jsonEncode(activeScenes.map((s) => s.toJson()).toList());
      saveOrUpdateUser(activeUser.value!);
    }
  }

  // --- SİSTEM ARAÇLARI ---
  void updateActiveUserVersionInfo(Map<String, dynamic> data) {
    if (activeUser.value == null) return;

    final user = activeUser.value!;
    user.version = (data['embeded'] ?? data['version'] ?? user.version).toString();
    user.totalChannels = int.tryParse((data['kanal'] ?? data['k'] ?? user.totalChannels).toString());
    user.wifi = int.tryParse((data['wifi'] ?? user.wifi).toString()) ?? 0;
    user.deviceadmin = data['admin']?.toString() ?? user.deviceadmin;
    user.mqttIP = data['mqtt']?.toString() ?? user.mqttIP;
    user.license = data['lic']?.toString() ?? user.license;
    user.deviceId = data['id']?.toString() ?? user.deviceId;
    user.ai = int.tryParse((data['ai'] ?? user.ai).toString());

    saveOrUpdateUser(user);
    debugPrint("SİSTEM: Aktif kullanıcı donanım bilgileri güncellendi.");
  }
}
