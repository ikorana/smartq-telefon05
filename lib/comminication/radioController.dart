import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class RadioStation {
  final String name;
  final String url;
  RadioStation(this.name, this.url);
}

class RadioController extends GetxController {
  final AudioPlayer _player = AudioPlayer();
  final RxBool isPlaying = false.obs;
  final Rxn<RadioStation> selectedStation = Rxn<RadioStation>();
  final RxDouble volume = 0.5.obs;

  final List<RadioStation> stations = [
    RadioStation("Alem FM", "http://turkmedya.radyotvonline.com/turkmedya/alemfm.stream/playlist.m3u8"),
    RadioStation("Radyo Viva", "http://46.20.3.230/;"),
    RadioStation("Best FM", "http://46.20.7.125/bestfmaac"),
    RadioStation("Kral FM", "http://kralwmp.radyotvonline.com/;"),
    RadioStation("Kral POP", "http://kralpopwmp.radyotvonline.com/;"),
    RadioStation("NTV Radyo", "http://ntvrdwmp.radyotvonline.com/;"),
    RadioStation("Radyo Viva (Alt)", "http://46.20.3.231/;"),
    RadioStation("Radyo Voyage", "http://voyagewmp.radyotvonline.com/;"),
    RadioStation("Show Radyo", "http://46.20.3.229/;"),
  ];

  @override
  void onInit() {
    super.onInit();
    selectedStation.value = stations.first;
    
    // Player durumlarını dinle
    _player.playerStateStream.listen((state) {
      isPlaying.value = state.playing;
    });
  }

  Future<void> togglePlay() async {
    if (isPlaying.value) {
      await stop();
    } else {
      if (selectedStation.value != null) {
        await playStation(selectedStation.value!);
      }
    }
  }

  Future<void> playStation(RadioStation station) async {
    try {
      selectedStation.value = station;
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(station.url),
          tag: MediaItem(
            id: station.url,
            album: "SmartQ Radio",
            title: station.name,
          ),
        ),
      );
      _player.play();
    } catch (e) {
      debugPrint("Radyo çalma hatası: $e");
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> setVolume(double val) async {
    volume.value = val;
    await _player.setVolume(val);
  }

  void handleIncomingValue(Map<String, dynamic> data) {
    if (data.containsKey('url')) {
      final station = RadioStation(data['name'] ?? "İnternet Radyo", data['url']);
      playStation(station);
    } else if (data.containsKey('com')) {
      final String com = data['com'];
      if (com == 'stop_radio') {
        stop();
      }
    }
  }

  void showRadioDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text("Radyo Ayarları"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("İstasyon Seçin", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Obx(() => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<RadioStation>(
                  value: stations.any((s) => s.url == selectedStation.value?.url) 
                    ? stations.firstWhere((s) => s.url == selectedStation.value?.url)
                    : null,
                  isExpanded: true,
                  hint: const Text("Seçiniz"),
                  items: stations.map((RadioStation s) {
                    return DropdownMenuItem<RadioStation>(
                      value: s,
                      child: Text(s.name),
                    );
                  }).toList(),
                  onChanged: (RadioStation? newValue) {
                    if (newValue != null) {
                      playStation(newValue);
                    }
                  },
                ),
              ),
            )),
            const SizedBox(height: 20),
            const Text("Ses Seviyesi", style: TextStyle(fontWeight: FontWeight.bold)),
            Obx(() => Slider(
              value: volume.value,
              onChanged: (val) {
                setVolume(val);
              },
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              stop();
              Get.back();
            }, 
            child: const Text("DURDUR", style: TextStyle(color: Colors.red))
          ),
          TextButton(onPressed: () => Get.back(), child: const Text("KAPAT")),
        ],
      ),
    );
  }

  @override
  void onClose() {
    _player.dispose();
    super.onClose();
  }
}
