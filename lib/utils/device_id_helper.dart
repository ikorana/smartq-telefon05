import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class DeviceIdHelper {
  static const _storage = FlutterSecureStorage();
  static const _key = 'permanent_device_uuid';
  
  static String? _cachedId;

  /// Kalıcı UUID'yi döndürür. Yoksa üretir ve kaydeder.
  static Future<String> getPersistentUUID() async {
    if (_cachedId != null) return _cachedId!;

    try {
      // Önce mevcut olanı oku
      String? id = await _storage.read(key: _key);

      if (id == null || id.isEmpty) {
        // Yoksa yeni üret
        id = const Uuid().v4();
        await _storage.write(key: _key, value: id);
        debugPrint("SİSTEM: Yeni kalıcı UUID üretildi: $id");
      } else {
        debugPrint("SİSTEM: Mevcut kalıcı UUID yüklendi: $id");
      }

      _cachedId = id;
      return id;
    } catch (e) {
      debugPrint("SİSTEM: UUID okuma/yazma hatası: $e");
      // Hata durumunda geçici bir ID döndür ama cache'leme
      return const Uuid().v4();
    }
  }
}
