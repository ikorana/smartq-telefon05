import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dashboardController.dart';
import 'keypad.dart';

class AlarmDialog extends StatefulWidget {
  final String message;

  const AlarmDialog({super.key, required this.message});

  @override
  State<AlarmDialog> createState() => _AlarmDialogState();
}

class _AlarmDialogState extends State<AlarmDialog> {
  late AudioPlayer _audioPlayer;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _playAlarmSound();
  }

  Future<void> _playAlarmSound() async {
    try {
      // Sesi döngüye al
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      // assets/audio/alarm3.mp3 dosyasını çal
      await _audioPlayer.play(AssetSource('audio/alarm3.mp3'));
    } catch (e) {
      debugPrint("Alarm sesi çalınırken hata: $e");
    }
  }

  @override
  void dispose() {
    // Dialog kapandığında sesi durdur ve temizle
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DashboardController>();

    return Material(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 30,
                spreadRadius: 10,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.warning_rounded,
                color: Colors.white,
                size: 140,
              ),
              const SizedBox(height: 40),
              Expanded(
                child: Center(
                  child: Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // SESİ KAPAT BUTONU
              if (!_isMuted)
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _audioPlayer.stop();
                      setState(() {
                        _isMuted = true;
                      });
                    },
                    icon: const Icon(Icons.volume_off),
                    label: const Text(
                      "SESİ KAPAT",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              // Sadece Tüm Alarmları Kapat butonu kaldı (ŞİFRELİ)
              SizedBox(
                width: double.infinity,
                height: 80,
                child: ElevatedButton(
                  onPressed: () async {
                    bool ok = await KeypadWidget.show(
                      message: "Alarmları Kapatmak İçin Şifre Girin",
                      password: "1210",
                    );
                    if (ok) {
                      controller.dismissAllAlarms();
                      Get.back();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 10,
                  ),
                  child: const Text(
                    "Tüm Alarmları KAPAT",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
