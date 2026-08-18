import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:get/get.dart';

final FlutterTts _flutterTts = FlutterTts();
final RxBool isSoundEnabled = true.obs;
// TTS motoru başlangıçta veya sonraki bir seslendirmede hata verirse false
// olur; ses kapalıyken de (isSoundEnabled=false) bu kontrolün etkisiz
// kalmaması için ayrı bir başlangıç kontrolü var (checkTtsAvailability).
final RxBool isTtsAvailable = true.obs;
final _storage = GetStorage();

/// TTS Ayarlarını yükle
void initTTS() {
  isSoundEnabled.value = _storage.read<bool>('isSoundEnabled') ?? true;
}

/// TTS motorunun gerçekten kullanılabilir olup olmadığını kontrol eder.
/// Ses kullanıcı tarafından kapatılmış olsa bile çalışır (mute durumu ayrı).
Future<void> checkTtsAvailability() async {
  try {
    await _flutterTts.setLanguage("tr-TR");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
    isTtsAvailable.value = true;
  } catch (e) {
    debugPrint("TTS motoru kullanılamıyor: $e");
    isTtsAvailable.value = false;
  }
}

/// Global olarak metin seslendirmeyi sağlayan fonksiyon
Future<void> speak(String text) async {
  if (text.isEmpty || !isSoundEnabled.value || !isTtsAvailable.value) return;

  try {
    await _flutterTts.speak(text);
  } catch (e) {
    debugPrint("Seslendirme hatası: $e");
    isTtsAvailable.value = false;
  }
}

/// Ses durumunu değiştir ve kaydet
void toggleSound() {
  isSoundEnabled.value = !isSoundEnabled.value;
  _storage.write('isSoundEnabled', isSoundEnabled.value);
}
