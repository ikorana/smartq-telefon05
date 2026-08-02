import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:get/get.dart';

final FlutterTts _flutterTts = FlutterTts();
final RxBool isSoundEnabled = true.obs;
final _storage = GetStorage();

/// TTS Ayarlarını yükle
void initTTS() {
  isSoundEnabled.value = _storage.read<bool>('isSoundEnabled') ?? true;
}

/// Global olarak metin seslendirmeyi sağlayan fonksiyon
Future<void> speak(String text) async {
  if (text.isEmpty || !isSoundEnabled.value) return;
  
  try {
    await _flutterTts.setLanguage("tr-TR");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(text);
  } catch (e) {
    debugPrint("Seslendirme hatası: $e");
  }
}

/// Ses durumunu değiştir ve kaydet
void toggleSound() {
  isSoundEnabled.value = !isSoundEnabled.value;
  _storage.write('isSoundEnabled', isSoundEnabled.value);
}
