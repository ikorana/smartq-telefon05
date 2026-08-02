import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../comminication/dataBridgeServis.dart';

class SaatT {
  int saat;
  int dakika;

  SaatT({this.saat = 0, this.dakika = 0});

  Map<String, dynamic> toJson() => {'saat': saat, 'dakika': dakika};

  factory SaatT.fromMap(Map<String, dynamic> map) {
    return SaatT(
      saat: int.tryParse(map['saat']?.toString() ?? '0') ?? 0,
      dakika: int.tryParse(map['dakika']?.toString() ?? '0') ?? 0,
    );
  }
}

class ZamanT {
  bool onactive;
  bool offactive;
  SaatT ontime;
  SaatT offtime;
  int power;

  ZamanT({
    this.onactive = false,
    this.offactive = false,
    SaatT? ontime,
    SaatT? offtime,
    this.power = 254,
  })  : ontime = ontime ?? SaatT(),
        offtime = offtime ?? SaatT();

  Map<String, dynamic> toJson() => {
        'onactive': onactive ? 1 : 0,
        'ontime': ontime.toJson(),
        'offactive': offactive ? 1 : 0,
        'offtime': offtime.toJson(),
        'power': power,
      };

  factory ZamanT.fromMap(Map<String, dynamic> map) {
    return ZamanT(
      onactive: (int.tryParse(map['onactive']?.toString() ?? '0') ?? 0) == 1,
      offactive: (int.tryParse(map['offactive']?.toString() ?? '0') ?? 0) == 1,
      ontime: SaatT.fromMap(Map<String, dynamic>.from(map['ontime'] ?? {})),
      offtime: SaatT.fromMap(Map<String, dynamic>.from(map['offtime'] ?? {})),
      power: int.tryParse(map['power']?.toString() ?? '254') ?? 254,
    );
  }
}

class GroupTimingDialog extends StatefulWidget {
  final String title;
  final int id;
  final String getCommand;
  final Function(ZamanT time1, ZamanT time2) onSave;

  const GroupTimingDialog({
    super.key,
    required this.title,
    required this.id,
    required this.onSave,
    this.getCommand = 'get_grp_time',
  });

  @override
  State<GroupTimingDialog> createState() => _GroupTimingDialogState();
}

class _GroupTimingDialogState extends State<GroupTimingDialog> {
  late ZamanT time1;
  late ZamanT time2;
  StreamSubscription? _dataSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    time1 = ZamanT();
    time2 = ZamanT();
    _startListening();
    
    // 3 saniye sonra veri gelmezse loading'i kapat
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });
  }

  void _startListening() {
    _dataSubscription = Get.find<DataBridgeService>().dataStream.listen((data) {
      final payload = data['full_payload'];
      if (payload is Map && payload['com'] == widget.getCommand) {
        final int? adres = int.tryParse(payload['adres']?.toString() ?? '');
        if (adres == widget.id) {
          debugPrint("--- [TIMING DIALOG] Veri Alındı: $payload ---");
          if (mounted) {
            setState(() {
              if (payload['time1'] != null) {
                time1 = ZamanT.fromMap(Map<String, dynamic>.from(payload['time1']));
              }
              if (payload['time2'] != null) {
                time2 = ZamanT.fromMap(Map<String, dynamic>.from(payload['time2']));
              }
              _isLoading = false;
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${widget.title} - ${'zamanlama'.tr}",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 20),
                  _buildTimeCard("Time 1", time1),
                  const SizedBox(height: 15),
                  _buildTimeCard("Time 2", time2),
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Get.back(),
                        child: Text('cancel'.tr, style: TextStyle(color: Colors.grey)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          widget.onSave(time1, time2);
                          Get.back();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('save'.tr),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeCard(String title, ZamanT zaman) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("ON", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        Transform.scale(
                          scale: 0.7,
                          child: Switch(
                            value: zaman.onactive,
                            onChanged: (val) => setState(() => zaman.onactive = val),
                          ),
                        ),
                      ],
                    ),
                    _buildTimePickerButton(zaman.ontime, (h, m) => setState(() {
                      zaman.ontime.saat = h;
                      zaman.ontime.dakika = m;
                    })),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("OFF", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        Transform.scale(
                          scale: 0.7,
                          child: Switch(
                            value: zaman.offactive,
                            onChanged: (val) => setState(() => zaman.offactive = val),
                          ),
                        ),
                      ],
                    ),
                    _buildTimePickerButton(zaman.offtime, (h, m) => setState(() {
                      zaman.offtime.saat = h;
                      zaman.offtime.dakika = m;
                    })),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text("${'brightness'.tr}: ", style: const TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: zaman.power.toDouble().clamp(0, 254),
                  min: 0,
                  max: 254,
                  divisions: 254,
                  label: zaman.power.toString(),
                  onChanged: (val) => setState(() => zaman.power = val.toInt()),
                ),
              ),
              Text(zaman.power.toString(), style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerButton(SaatT saat, Function(int h, int m) onPicked) {
    final theme = Theme.of(context);
    final String timeStr = "${saat.saat.toString().padLeft(2, '0')}:${saat.dakika.toString().padLeft(2, '0')}";

    return InkWell(
      onTap: () async {
        final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: saat.saat, minute: saat.dakika),
        );
        if (picked != null) {
          onPicked(picked.hour, picked.minute);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(timeStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
