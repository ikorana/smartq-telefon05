import 'dart:async';
import 'udp.dart';
import 'comminication.dart';

class DiscoveredDevice {
  final String ip;
  final String id;
  final String version;
  final int kanal;
  final String admin;
  final String? mqtt;
  final String? lic;
  final int? wifi;
  final int? ai;

  DiscoveredDevice({
    required this.ip,
    required this.id,
    required this.version,
    required this.kanal,
    required this.admin,
    this.mqtt,
    this.lic,
    this.wifi,
    this.ai,
  });
}

class NetworkScanner {
  /// Projedeki mevcut UdpService üzerinden cihazları tarar.
  /// [targetIp] belirtilirse unicast, belirtilmezse broadcast sorgu gönderilir.
  static Future<List<DiscoveredDevice>> discover({String? targetIp}) async {
    final List<DiscoveredDevice> devices = [];
    final udp = UdpService();
    
    print("--- [Discovery] Tarama başlatıldı (Hedef: ${targetIp ?? 'BROADCAST'})... ---");

    // Tarama süresince gelen mesajları dinle
    final subscription = udp.messages.listen((msg) {
      // GELEN TÜM PAKETLERİ LOGLA
      print("--- [Discovery] Gelen Paket: $msg");

      try {
        final payload = msg['full_payload'];
        final originalRequest = msg['original_request'];
        
        bool isCorrectResponse = false;

        // 1. Durum: Ham/Broadcast cevabı (payload içinde komut adı var)
        if (payload is Map && (payload['com'] == 'get_version' || payload['c'] == 'gv')) {
          isCorrectResponse = true;
        } 
        // 2. Durum: Unicast AK cevabı (orijinal istek get_version idi)
        else if (msg['type'] == 'AK' && originalRequest is Map) {
          if (originalRequest['com'] == 'get_version' || originalRequest['c'] == 'gv') {
            isCorrectResponse = true;
          }
        }

        if (isCorrectResponse && payload is Map) {
          print("--- [Discovery] Geçerli cihaz bulundu: ${msg['address']}");

          final device = DiscoveredDevice(
            ip: msg['address'],
            id: payload['id']?.toString() ?? 'unknown',
            version: (payload['embeded'] ?? payload['version'] ?? '1.0.0').toString(),
            kanal: int.tryParse((payload['kanal'] ?? payload['k'] ?? '0').toString()) ?? 0,
            admin: payload['admin']?.toString() ?? 'false',
            mqtt: payload['mqtt']?.toString(),
            lic: payload['lic']?.toString(),
            wifi: int.tryParse((payload['wifi'] ?? '0').toString()) ?? 0,
            ai: int.tryParse((payload['ai'] ?? '0').toString()) ?? 0,
          );

          // Aynı IP'li cihazı tekrar ekleme
          if (!devices.any((d) => d.ip == device.ip)) {
            devices.add(device);
          }
        }
      } catch (e) {
        print("--- [Discovery] İşleme Hatası: $e");
      }
    });

    final message = {"com": "get_version", "type": 2};

    // 1. Sorgu paketini gönder
    if (targetIp != null && targetIp.isNotEmpty) {
      print("--- [Discovery] Unicast sorgu gönderiliyor: $targetIp ---");
      final owner = MessageOwner(
        transmission: TransmissionType.udp,
        ip: targetIp,
        port: 53250,
      );
      udp.sendUnicast(message, owner);
    } else {
      print("--- [Discovery] Broadcast sorgu gönderiliyor... ---");
      udp.sendBroadcast(message);
    }

    // 2. Cevaplar için bekle (3 saniye)
    await Future.delayed(const Duration(seconds: 3));

    // 3. Dinlemeyi durdur ve sonuçları dön
    print("--- [Discovery] Tarama bitti. Bulunan cihaz sayısı: ${devices.length} ---");
    await subscription.cancel();
    return devices;
  }
}
