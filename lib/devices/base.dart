import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:telefon05/devices/relay.dart';
import 'package:telefon05/devices/rgb.dart';
import 'package:telefon05/devices/energy.dart';
import 'package:telefon05/devices/gas.dart';
import 'package:telefon05/devices/asansor.dart';
import 'package:telefon05/devices/water.dart';
import 'package:telefon05/devices/priz.dart';
import 'package:telefon05/devices/mwater.dart';
import 'package:telefon05/devices/door.dart';
import 'package:telefon05/devices/garage.dart';
import 'package:telefon05/devices/relay_lamp.dart';
import 'package:telefon05/devices/radio.dart';

import 'LogicButton.dart';
import 'TermostatButton.dart';
import 'anahtar.dart';
import 'blind.dart';
import 'lamp.dart';


enum DeviceType {
  Lanahtar(typeCode: 0, name: "Lojik Anahtar"),
  term(typeCode: 3, name: "Termostat"),
  button(typeCode: 5, name: "Fiziksel Düğme"),
  lamp(typeCode: 6, name: "Aydınlatma"),
  relay(typeCode: 7, name: "Röle"),
  anahtar(typeCode: 7, exttype: 0x0B, name: "Anahtar Cihazı"),
  blind(typeCode: 7, exttype: 0x77, name: "Panjur/Perde"),
  relaylamp(typeCode: 7, exttype: 0x76, name: "Röle Lamba"),
  rgb(typeCode: 8, name: "RGB Aydınlatma"),
  energy(typeCode: 7, exttype: 0x78, name: "Enerji Takibi"),
  water(typeCode: 7, exttype: 0x79, name: "Su Valfi"),
  gas(typeCode: 7, exttype: 0x7A, name: "Gaz /Valfi"),
  asansor(typeCode: 7, exttype: 0x7B, name: "Asansör"),
  socket(typeCode: 7, exttype: 0x7C, name: "Akıllı Priz"),
  mwater(typeCode: 7, exttype: 0x7D, name: "Motorlu Su Valfi"),
  door(typeCode: 7, exttype: 0x7E, name: "Kapı/Kilit"),
  garage(typeCode: 7, exttype: 0x7F, name: "Garaj Kapısı"),
  radio(typeCode: 20, name: "İnternet Radyo");
  

  final int typeCode;
  final int exttype;
  final String? name;

  const DeviceType({required this.typeCode, this.exttype = 0, this.name});

  static DeviceType fromIndex(int code, [int ext = 0]) {
    return DeviceType.values.firstWhere(
          (e) => e.typeCode == code && e.exttype == ext,
      orElse: () => DeviceType.values.firstWhere(
            (e) => e.typeCode == code,
        orElse: () => DeviceType.lamp,
      ),
    );
  }
}

abstract class BaseDevice {
  final int id;              // gr: Dali Adresi
  final RxnString rxName = RxnString(); // Reaktif İsim
  String? get name => rxName.value;
  set name(String? val) => rxName.value = val;

  final int type;            // tp: Cihaz Tipi İndeksi
  final int extension;       // ex: Alt cihaz tipi
  final int channel;         // pr: Donanım Kanalı
  int ico;                   // ico: Icon (Düzenlenebilir)
  final RxInt rxRoomId = 0.obs; // Reaktif Oda ID
  int get roomId => rxRoomId.value;
  set roomId(int val) => rxRoomId.value = val;

  final int instance;        // in: Cihaz İçi Örnek/Birim
  int localGroupId;          // lg: Yerel Grup ID
  int localGroupAction;      // lga: Yerel Grup Aksiyonu
  final RxInt rxLogicButtonId = 0.obs; // Reaktif Logic Anahtar ID
  int get logicButtonId => rxLogicButtonId.value;
  set logicButtonId(int val) => rxLogicButtonId.value = val;

  DeviceType get deviceType => DeviceType.fromIndex(type, extension);

  BaseDevice({
    required this.id,
    required String? name,
    required this.type,
    required this.extension,
    required this.channel,
    required this.ico,
    required int roomId,
    required this.instance,
    this.localGroupId = 0,
    this.localGroupAction = 0,
    int logicButtonId = 0,
  }) {
    rxName.value = name;
    rxRoomId.value = roomId;
    rxLogicButtonId.value = logicButtonId;
  }

  BaseDevice.fromMap(Map<String, dynamic> map)
      : id = map['gr'] ?? 0,
        type = map['tp'] ?? 6,
        extension = map['ex'] ?? 0,
        channel = map['pr'] ?? 0,
        ico = map['ico'] ?? 0,
        instance = map['in'] ?? 0,
        localGroupId = map['lg'] ?? 0,
        localGroupAction = map['lga'] ?? 0 {
    rxName.value = map['nm'] ?? "";
    rxRoomId.value = map['vr'] ?? 0;
    rxLogicButtonId.value = map['an'] ?? 0;
  }

  Map<String, dynamic> toMap() => {
        'gr': id,
        'nm': rxName.value,
        'tp': type,
        'ex': extension,
        'pr': channel,
        'ico': ico,
        'vr': rxRoomId.value,
        'in': instance,
        'lg': localGroupId,
        'lga': localGroupAction,
        'an': rxLogicButtonId.value,
      };

  factory BaseDevice.createFromMap(Map<String, dynamic> map) {
    final int typeCode = map['tp'] ?? 6;
    final int extension = map['ex'] ?? 0;
    final String? name = map['nm'] ?? "";

    print("Device Type: $typeCode, Extension: $extension, Name: $name");
    
    if (typeCode == 6) {
      return LampDevice.fromMap(map);
    } else if (typeCode == 7) {
      if (extension == 0x7C) return PrizDevice.fromMap(map);
      if (extension == 0x7D) return MWaterDevice.fromMap(map);
      if (extension == 0x7E) return DoorDevice.fromMap(map);
      if (extension == 0x7F) return GarageDevice.fromMap(map);
      if (extension == 0x76) return RelayLampDevice.fromMap(map);
      if (extension == 7) return RelayDevice.fromMap(map);
      if (extension == 0x0B) return AnahtarDevice.fromMap(map);
      if (extension == 0x77) return BlindDevice.fromMap(map);
      if (extension == 0x78) return EnergyDevice.fromMap(map);
      if (extension == 0x79) return WaterDevice.fromMap(map);
      if (extension == 0x7A) return GasDevice.fromMap(map);
      if (extension == 0x7B) return AsansorDevice.fromMap(map);
    } else if (typeCode == DeviceType.Lanahtar.typeCode) {
      return LButtonDevice.fromMap(map);
    } else if (typeCode == DeviceType.term.typeCode) {
      return ThermostatDevice.fromMap(map);
    } else if (typeCode == DeviceType.rgb.typeCode) {
      return RGBDevice.fromMap(map);
    } else if (typeCode == 20) {
      return RadioDevice.fromMap(map);
    }


    return GenericDevice.fromMap(map);
  }

  Widget buildWidget();
  void handleIncomingValue(dynamic value);
}

// Concrete class for devices that don't have a specific implementation yet
class GenericDevice extends BaseDevice {
  GenericDevice.fromMap(super.map) : super.fromMap();

  @override
  Widget buildWidget() => const SizedBox.shrink();

  @override
  void handleIncomingValue(dynamic value) {}
}
