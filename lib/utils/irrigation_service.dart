import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:tftp/tftp.dart';
import 'package:path_provider/path_provider.dart';
import '../comminication/dataBridgeServis.dart';
import '../models/irrigation_system.dart';
import '../user/userManagementService.dart';

class IrrigationService extends GetxService {
  final _userManager = Get.find<UserManagementService>();

  /// Ana cihazdan (veya demodan) sulama konfigürasyonunu çeker
  Future<IrrigationSystem?> getConfiguration() async {
    final user = _userManager.activeUser.value;
    
    // DEMO MODU kontrolü
    if (user?.id == "demo_user_01") {
      await Future.delayed(const Duration(milliseconds: 500)); // Simülasyon gecikmesi
      return IrrigationSystem.fromJson(_demoJson);
    }

    final String? deviceIp = user?.deviceIp;
    if (deviceIp == null || deviceIp.isEmpty) {
      print("SİSTEM: Cihaz IP'si bulunamadı, demo verisi dönülüyor.");
      return IrrigationSystem.fromJson(_demoJson);
    }

    try {
      print("SİSTEM: TFTP ile $deviceIp üzerinden irrigation.json çekiliyor...");
      
      final client = await TFtpClient.bind("0.0.0.0", 0);
      final tempDir = await getTemporaryDirectory();
      final localPath = "${tempDir.path}/irrigation.json";
      
      await client.get(localPath, "irrigation.json", deviceIp, 69).timeout(const Duration(seconds: 5));
      
      final file = File(localPath);
      if (await file.exists()) {
        final String jsonString = await file.readAsString();
        final Map<String, dynamic> jsonData = jsonDecode(jsonString);
        print("SİSTEM: Sulama yapılandırması başarıyla çekildi.");
        return IrrigationSystem.fromJson(jsonData);
      }
    } catch (e) {
      print("SİSTEM: TFTP Hatası: $e. Demo verisi kullanılıyor.");
    }

    return IrrigationSystem.fromJson(_demoJson);
  }

  /// Belirli bir sulama programını başlatma komutu gönderir
  void startSchedule(String startTime) {
    final message = {
      "com": "run_schedule",
      "time": startTime
    };
    
    Get.find<DataBridgeService>().send(message);
    print("SİSTEM: Sulama programı başlatma komutu gönderildi: $startTime");
  }

  /// Sulama sistemini tamamen durdurma komutu gönderir
  void stopIrrigation({String? stat}) {
    final message = {
      "com": "stop_irrigation"
    };
    if (stat != null) {
      message["stat"] = stat;
    }
    
    Get.find<DataBridgeService>().send(message);
    print("SİSTEM: Sulama DURDURMA komutu gönderildi. Stat: $stat");
  }

  /// Belirli bir segmenti manuel olarak başlatma komutu gönderir
  void startSegment({required int segmentId, required int relayId, required int time}) {
    final message = {
      "com": "run_irrpin",
      "segment_id": segmentId,
      "relay_id": relayId,
      "time": time
    };
    
    Get.find<DataBridgeService>().send(message);
    print("SİSTEM: Segment başlatma komutu gönderildi: Seg:$segmentId, Rel:$relayId, Time:$time");
  }

  /// Sistem ve Akıllı Sistem ayarlarını değiştirme komutu gönderir
  void updateSystemSettings({required String status, required int smart}) {
    final message = {
      "com": "chg_irr",
      "sistem": status,
      "smart": smart
    };
    
    Get.find<DataBridgeService>().send(message);
    print("SİSTEM: Sulama ayarları güncelleme komutu gönderildi: $status, Smart:$smart");
  }

  /// Sulama durumunu ana cihazdan sorgular
  void getIrrigationStatus() {
    final message = {
      "com": "get_irrigation"
    };
    Get.find<DataBridgeService>().send(message);
    print("SİSTEM: Sulama DURUMU sorgulanıyor...");
  }

  final Map<String, dynamic> _demoJson = {
    "system_id": "GARDEN_01",
    "name": "Bahçe Sulama Sistemi",
    "status": "enabled",
    "smart": 1,
    "hardware": {
      "motor": {
        "id": 1,
        "name": "Pompa",
        "type": "relay",
        "start_delay_ms": 2000
      },
      "sensors": [
        {
          "type": "rain_sensor",
          "id": 0,
          "name": "Yeni Sensör"
        }
      ],
      "segments": [
        {
          "id": 1,
          "relay_id": 2,
          "name": "1. bölge",
          "x": 0.0,
          "y": 0.0,
          "isPlaced": false
        },
        {
          "id": 2,
          "relay_id": 3,
          "name": "2. bölge",
          "x": 0.0,
          "y": 0.0,
          "isPlaced": false
        }
      ]
    },
    "schedules": [
      {
        "id": "1783252370343",
        "start_time": "05:30",
        "active_days": ["Mon", "Wed", "Fri"],
        "overlap_seconds": 3,
        "durations": [
          {"id": 1, "segment_id": 1, "relay_id": 2, "time": 5},
          {"id": 2, "segment_id": 2, "relay_id": 3, "time": 10}
        ]
      },
      {
        "id": "1783252954418",
        "start_time": "05:30",
        "active_days": ["Tue", "Thu", "Sat", "Sun"],
        "overlap_seconds": 3,
        "durations": [
          {"id": 1, "segment_id": 1, "relay_id": 2, "time": 10},
          {"id": 2, "segment_id": 2, "relay_id": 3, "time": 10}
        ]
      }
    ]
  };
}
