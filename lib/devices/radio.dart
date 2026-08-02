import 'package:flutter/material.dart';
import 'base.dart';

class RadioDevice extends BaseDevice {
  RadioDevice({
    required super.id,
    required super.name,
    required super.extension,
    required super.channel,
    required super.ico,
    required super.roomId,
    required super.instance,
  }) : super(type: 20);

  RadioDevice.fromMap(Map<String, dynamic> map) : super.fromMap(map);

  @override
  void handleIncomingValue(dynamic value) {
    // Topbar'daki global radyo kontrolü için bir köprü kurulabilir
    // Ancak şimdilik kart olarak gösterilmediği için boş bırakıyoruz
  }

  @override
  Widget buildWidget() {
    // Radyo artık bir kart olarak gösterilmiyor, Topbar'a taşındı
    return const SizedBox.shrink();
  }
}
