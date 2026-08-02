import 'dart:convert';
import '../devices/base.dart';

class ChannelMenu {
  final String name;
  final int channel;

  ChannelMenu({required this.name, required this.channel});
}

class RoomInfo {
  final int id;
  final String name;

  RoomInfo({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory RoomInfo.fromJson(Map<String, dynamic> json) => RoomInfo(
    id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
    name: json['name']?.toString() ?? json['nm']?.toString() ?? '',
  );
}

class GrpInfo {
  final int id;
  final String name;
  final int icon;

  GrpInfo({required this.id, required this.name, required this.icon});

  Map<String, dynamic> toJson() => {'id': id, 'nm': name, 'ico':icon};
  factory GrpInfo.fromJson(Map<String, dynamic> json) => GrpInfo(
    id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
    name: json['nm']?.toString() ?? json['nm']?.toString() ?? '',
    icon: json['ico'] is int ? json['ico'] : int.parse(json['ico'].toString()),
  );
}

class ScnInfo {
  final int id;
  final String name;
  final int icon;

  ScnInfo({required this.id, required this.name, required this.icon});

  Map<String, dynamic> toJson() => {'id': id, 'nm': name, 'ico':icon};
  factory ScnInfo.fromJson(Map<String, dynamic> json) => ScnInfo(
    id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
    name: json['nm']?.toString() ?? json['nm']?.toString() ?? '',
    icon: json['ico'] is int ? json['ico'] : int.parse(json['ico'].toString()),
  );
}

class SwitchInfo {
  final int type;
  final int id;
  final String name;
  final int icon;
  final int level;
  final int sensorId;
  final int sensorInstance;
  final int relayId;
  final int relayChannel;
  final int room;
  final int? set;
  final int? ttpe; // 0: Isıtma, 1: Soğutma

  SwitchInfo({
    required this.type,
    required this.id,
    required this.name,
    required this.icon,
    required this.level,
    required this.sensorId,
    required this.sensorInstance,
    required this.relayId,
    required this.relayChannel,
    required this.room,
    this.set,
    this.ttpe,
  });

  Map<String, dynamic> toJson() => {
    'tp': type,
    'id': id,
    'nm': name,
    'ico': icon,
    'level': level,
    'sens_id': sensorId,
    'sens_ins': sensorInstance,
    'rel_id': relayId,
    'rel_chn': relayChannel,
    'room': room,
    'set': set,
    'ttpe': ttpe,
  };

  factory SwitchInfo.fromJson(Map<String, dynamic> json) => SwitchInfo(
    type: json['tp'] is int ? json['tp'] : int.parse(json['tp']?.toString() ?? '0'),
    id: json['id'] is int ? json['id'] : int.parse(json['id']?.toString() ?? '0'),
    name: json['nm']?.toString() ?? '',
    icon: json['ico'] is int ? json['ico'] : int.parse(json['ico']?.toString() ?? '0'),
    level: json['level'] is int ? json['level'] : int.parse(json['level']?.toString() ?? '0'),
    sensorId: json['sens_id'] is int ? json['sens_id'] : int.parse(json['sens_id']?.toString() ?? '0'),
    sensorInstance: json['sens_ins'] is int ? json['sens_ins'] : int.parse(json['sens_ins']?.toString() ?? '0'),
    relayId: json['rel_id'] is int ? json['rel_id'] : int.parse(json['rel_id']?.toString() ?? '0'),
    relayChannel: json['rel_chn'] is int ? json['rel_chn'] : int.parse(json['rel_chn']?.toString() ?? '0'),
    room: json['room'] is int ? json['room'] : int.parse(json['room']?.toString() ?? '0'),
    set: json['set'] is int? ? json['set'] : (json['set'] != null ? int.tryParse(json['set'].toString()) : null),
    ttpe: json['ttpe'] is int? ? json['ttpe'] : (json['ttpe'] != null ? int.tryParse(json['ttpe'].toString()) : null),
  );
}

class InsIntroScn {
  final int adr;
  final int iadr;
  final int chn;
  final int type;
  final int act; 
  final int proc;
  final int cm;
  final int cmadr;
  final int stat;
  final int temp;
  final int tset;
  final int ttype;

  InsIntroScn({
    required this.adr,
    required this.iadr,
    required this.chn,
    required this.type,
    required this.act,
    required this.proc,
    required this.cm,
    required this.cmadr,
    required this.stat,
    required this.temp,
    required this.tset,
    required this.ttype,
  });

  Map<String, dynamic> toJson() => {
    'adr': adr,
    'iadr': iadr,
    'chn': chn,
    'type': type,
    'act': act,
    'proc': proc,
    'cm': cm,
    'cmadr': cmadr,
    'stat': stat,
    'temp': temp,
    'tset': tset,
    'ttype': ttype,
  };

  factory InsIntroScn.fromJson(Map<String, dynamic> json) => InsIntroScn(
    adr: int.tryParse(json['adr']?.toString() ?? '0') ?? 0,
    iadr: int.tryParse((json['iadr'] ?? json['ins'] ?? '0').toString()) ?? 0,
    chn: int.tryParse(json['chn']?.toString() ?? '0') ?? 0,
    type: int.tryParse(json['type']?.toString() ?? '0') ?? 0,
    act: int.tryParse(json['act']?.toString() ?? '0') ?? 0,
    proc: int.tryParse((json['proc'] ?? json['pro'] ?? '0').toString()) ?? 0,
    cm: int.tryParse((json['cm'] ?? json['cmtype'] ?? '0').toString()) ?? 0,
    cmadr: int.tryParse(json['cmadr']?.toString() ?? '0') ?? 0,
    stat: int.tryParse(json['stat']?.toString() ?? '0') ?? 0,
    temp: int.tryParse(json['temp']?.toString() ?? '0') ?? 0,
    tset: int.tryParse(json['tset']?.toString() ?? '0') ?? 0,
    ttype: int.tryParse(json['ttype']?.toString() ?? '0') ?? 0,
  );

  InsIntroScn copyWith({
    int? adr,
    int? iadr,
    int? chn,
    int? type,
    int? act,
    int? proc,
    int? cm,
    int? cmadr,
    int? stat,
    int? temp,
    int? tset,
    int? ttype,
  }) {
    return InsIntroScn(
      adr: adr ?? this.adr,
      iadr: iadr ?? this.iadr,
      chn: chn ?? this.chn,
      type: type ?? this.type,
      act: act ?? this.act,
      proc: proc ?? this.proc,
      cm: cm ?? this.cm,
      cmadr: cmadr ?? this.cmadr,
      stat: stat ?? this.stat,
      temp: temp ?? this.temp,
      tset: tset ?? this.tset,
      ttype: ttype ?? this.ttype,
    );
  }
}

class AppUser {
  String name;
  String id;
  String? phoneNumber; // Telefon numarası alanı eklendi
  int themeIndex; 
  bool isAdmin;
  String language;

  // Cihaz Bilgileri (Kalıcı - Kaydedilir)
  String? deviceIp;
  String? mqttIP;
  String? license; 
  String? deviceId;
  String? version;
  String? deviceadmin;
  int? ai; // AI özelliği aktif mi?
  int? totalChannels;
  int? wifi;

  // JSON String olarak saklanacak veriler (Kalıcı - Kaydedilir)
  String? rooms;
  String? devices;
  String? group;
  String? scene;
  String? switches;
  String? insIntro; // JSON string saklama alanı

  // --- RUNTIME VERİLERİ ---
  List<RoomInfo> roomList = [];
  List<BaseDevice> deviceList = [];
  List<GrpInfo> groupList = [];
  List<ScnInfo> sceneList = [];
  List<SwitchInfo> switchList = [];
  List<InsIntroScn> insIntroList = []; // Liste olarak saklama alanı

  List<ChannelMenu> channelMenus = []; //Cihaz kanal Menusu

  AppUser({
    required this.name,
    required this.id,
    this.phoneNumber,
    this.themeIndex = 1, // Default to industrialDark
    this.isAdmin = false,
    this.language = 'tr',
    this.deviceIp,
    this.mqttIP,
    this.license,
    this.deviceId,
    this.version,
    this.totalChannels,
    this.wifi = 0,
    this.rooms,
    this.devices,
    this.group,
    this.scene,
    this.switches,
    this.insIntro,
    this.deviceadmin,
    this.ai = 1,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final user = AppUser(
      name: json['name']?.toString() ?? 'Default',
      id: json['id']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString(),
      themeIndex: json['themeIndex'] is int ? json['themeIndex'] : (json['theme'] is bool ? (json['theme'] ? 1 : 0) : 1),
      isAdmin: json['isAdmin'] is bool ? json['isAdmin'] : false,
      language: json['language']?.toString() ?? 'tr',
      deviceIp: json['deviceIp']?.toString(),
      mqttIP: json['mqttIP']?.toString(),
      license: json['license']?.toString(),
      deviceId: json['deviceId']?.toString(),
      version: json['version']?.toString(),
      totalChannels: json['totalChannels'] is int ? json['totalChannels'] : null,
      wifi: json['wifi'] is int ? json['wifi'] : 0,
      rooms: json['rooms']?.toString(),
      devices: json['devices']?.toString(),
      group: json['group']?.toString(),
      scene: json['scene']?.toString(),
      switches: json['switches']?.toString(),
      insIntro: json['insIntro']?.toString(),
      deviceadmin: json['deviceadmin']?.toString(),
      ai: json['ai'] is int ? json['ai'] : (json['ai'] != null ? int.tryParse(json['ai'].toString()) : 1),
    );
    return user;
  }

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "id": id,
      "phoneNumber": phoneNumber,
      "themeIndex": themeIndex,
      "isAdmin": isAdmin,
      "language": language,
      "deviceIp": deviceIp,
      "mqttIP": mqttIP,
      "license": license,
      "deviceId": deviceId,
      "version": version,
      "totalChannels": totalChannels,
      "wifi": wifi,
      "rooms": rooms,
      "devices": devices,
      "group": group,
      "scene": scene,
      "switches": switches,
      "insIntro": insIntro,
      "deviceadmin": deviceadmin,
      "ai": ai,
    };
  }

  AppUser copyWith({
    String? name,
    String? phoneNumber,
    bool? isAdmin,
    String? deviceIp,
    String? mqttIP,
    String? license,
    String? rooms,
    String? devices,
    String? group,
    String? scene,
    String? switches,
    String? insIntro,
    int? themeIndex,
    int? ai,
    int? totalChannels,
    int? wifi,
  }) {
    final newUser = AppUser(
      name: name ?? this.name,
      id: this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      themeIndex: themeIndex ?? this.themeIndex,
      isAdmin: isAdmin ?? this.isAdmin,
      language: language ?? this.language,
      deviceIp: deviceIp ?? this.deviceIp,
      mqttIP: mqttIP ?? this.mqttIP,
      license: license ?? this.license,
      deviceId: deviceId ?? this.deviceId,
      version: version ?? this.version,
      totalChannels: totalChannels ?? this.totalChannels,
      wifi: wifi ?? this.wifi,
      rooms: rooms ?? this.rooms,
      devices: devices ?? this.devices,
      group: group ?? this.group,
      scene: scene ?? this.scene,
      switches: switches ?? this.switches,
      insIntro: insIntro ?? this.insIntro,
      deviceadmin: deviceadmin ?? this.deviceadmin,
      ai: ai ?? this.ai,
    );

    newUser.roomList = this.roomList;
    newUser.deviceList = this.deviceList;
    newUser.groupList = this.groupList;
    newUser.sceneList = this.sceneList;
    newUser.switchList = this.switchList;
    newUser.insIntroList = this.insIntroList;

    return newUser;
  }
}
