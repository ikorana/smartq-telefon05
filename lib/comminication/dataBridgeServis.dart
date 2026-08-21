import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../devices/TermostatButton.dart';
import 'radioController.dart';
import 'udp.dart';
import 'mqttService.dart';
import 'comminication.dart';
import '../user/userManagementService.dart';
import '../utils/tts_helper.dart';
import '../main.dart';

class DataBridgeService extends GetxService {
  static final DataBridgeService _instance = DataBridgeService._internal();
  factory DataBridgeService() => _instance;
  DataBridgeService._internal();

  final UdpService _udpService = UdpService();
  final MqttService _mqttService = Get.find<MqttService>();
  final ComminicationServis _commServis = Get.find<ComminicationServis>();
  final UserManagementService _userManager = Get.find<UserManagementService>();

  final _dataController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;

  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  void _init() {
    // KRİTİK: UDP Servisinden gelen mesajları dinle
    _udpService.messages.listen((udpData) {
      if (udpData['type'] == 'error') {
        _log("!!! UDP SİSTEM HATASI: ${udpData['body']}");
      } else {
        _handleIncomingMessage(udpData, TransmissionType.udp);
      }
    }, onError: (err) {
      debugPrint(">>> [DATA-BRIDGE] UDP Dinleme Hatası: $err");
    });

    _mqttService.messages.listen((mqttData) {
      _handleIncomingMessage(mqttData, TransmissionType.mqtt);
    });
  }

  void _handleIncomingMessage(Map<String, dynamic> data, TransmissionType source) {
    // UI'daki terminale ham veri kaydı
    if (data['type'] == 'PONG' || data['type'] == 'error') return;

    try {
      String type = 'RAW';
      String id = '0';
      dynamic payload;

      if (data.containsKey('full_payload')) {
        payload = data['full_payload'];
        type = data['type'] ?? 'RAW';
        id = data['id']?.toString() ?? '0';
      } else {
        if (data.containsKey('pck') && data.containsKey('payload')) {
          type = data['pck']['type']?.toString() ?? 'RAW';
          id = data['pck']['id']?.toString() ?? '0';
          payload = data['payload'];
        } else if (data.containsKey('p') && data.containsKey('l')) {
          type = data['p']['t']?.toString() ?? 'RAW';
          id = data['p']['i']?.toString() ?? '0';
          payload = data['l'];
        } else {
          payload = data;
        }
      }

      // MQTT Mesajlarını loglayalım (push_temp çok sık geldiği için hariç tutuluyor)
      if (source == TransmissionType.mqtt) {
        final dynamic mqttCom = payload is Map ? payload['com'] : null;
        if (mqttCom != 'push_temp') {
          _log("MQTT Gelen: ${payload is Map ? (mqttCom ?? payload) : payload}");
        }
      }

      if (payload is Map) {
        final Map<String, dynamic> payloadMap = Map<String, dynamic>.from(payload);
        final String? com = payloadMap['com'];
        if (com == null) return;
        final int? adres = int.tryParse(payloadMap['adr']?.toString() ?? payloadMap['adres']?.toString() ?? '');
        final int? kanal = int.tryParse(payloadMap['kanal']?.toString() ?? '');

        if (com == 'set_instance' && type == 'AK') {
          _userManager.updateSingleInsIntro(payloadMap);
        }

        if (com == 'say' && payloadMap.containsKey('txt')) {
          speak(payloadMap['txt'].toString());
        }

        if (com == 'voice' && payloadMap.containsKey('txt')) {
          Get.snackbar(
            "SmartQ AI",
            payloadMap['txt'].toString(),
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Get.theme.colorScheme.primary.withValues(alpha: 0.8),
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.all(15),
            borderRadius: 15,
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
          );
        }

        if (com == 'radio' || payloadMap.containsKey('url')) {
          Get.find<RadioController>().handleIncomingValue(payloadMap);
        }

        // push_temp mesajı işleme (Broadcast)
        if (com == 'push_temp') {
          final int? pAdres = int.tryParse(payloadMap['adres']?.toString() ?? '');
          final int? pIns = int.tryParse(payloadMap['ins']?.toString() ?? '');

          if (pAdres != null && pIns != null) {
            final termostats = _userManager.activeLogicDevices
                .whereType<ThermostatDevice>()
                .where((t) => t.sensorId == pAdres && t.sensorInstance == pIns)
                .toList();

            for (var t in termostats) {
              t.handleIncomingValue(payloadMap);
            }
          }
        }

        //Cihazı bul
        if (adres != null && kanal != null) {
          final device = _userManager.activeDevices.firstWhereOrNull(
                  (d) => d.id == adres && d.channel == kanal
          );
          //Device varsa
          if (device!=null)
            {
              if (com == 'status') {
                device.handleIncomingValue({
                  'level': payloadMap['level'],
                  'low': payloadMap['grp0'],
                  'high': payloadMap['grp1'],
                  'is_passive_update': true
                });
              }
              if (com == 'get_gurup' || com == 'set_gurup') {
                device.handleIncomingValue({
                  'low': payloadMap['low'],
                  'high': payloadMap['high']
                });
              }
              if (com == 'get_level') {
                device.handleIncomingValue(payloadMap['power']);
              }
              if (com == 'qstatus') {
                device.handleIncomingValue({'status': payloadMap['status']});
              }
              if (com == 'scene_status') {
                device.handleIncomingValue({
                  'scene_status': true,
                  'scene': int.tryParse(payloadMap['scene']?.toString() ?? '0') ?? 0,
                  'value': int.tryParse(payloadMap['value']?.toString() ?? '0') ?? 0,
                });
              }
              if (com.startsWith('get_') || com.startsWith('set_')) {
                device.handleIncomingValue(payloadMap);
              }
            }
        }

        if (com.startsWith('an_')) {
          final int? anId = int.tryParse(payloadMap['id']?.toString() ?? '');
          if (anId != null) {
            final logicDev = _userManager.activeLogicDevices.firstWhereOrNull((d) => d.id == anId);
            if (logicDev != null) {
              logicDev.handleIncomingValue(payloadMap);
            }
          }
        }

        // push_temp mesajı işleme (Broadcast)
        if (com == 'push_temp') {
          final int? pAdres = int.tryParse(payloadMap['adres']?.toString() ?? '');
          final int? pIns = int.tryParse(payloadMap['ins']?.toString() ?? '');

          if (pAdres != null && pIns != null) {
            final termostats = _userManager.activeLogicDevices
                .whereType<ThermostatDevice>()
                .where((t) => t.sensorId == pAdres && t.sensorInstance == pIns)
                .toList();

            for (var t in termostats) {
              t.handleIncomingValue(payloadMap);
            }
          }
        }

        bool isSearchMessage = (payload['com'] == 'search');
        if (isSearchMessage) {
          _log("    ${payloadMap['txt']}");
        }

        bool isMessage = (payload['com'] == 'log');
        if (isMessage) {
          _log("    ${payloadMap['txt']}");
        }


        // SADECE GET_VERSION CEVABINI LOGDA GÖSTERİYORUZ
        if (com == 'get_version') {
           _log("--- SİSTEM BİLGİLERİ ---");
           _log("Versiyon: ${payloadMap['embeded'] ?? payloadMap['version']}");
           _log("ID: ${payloadMap['id']}");
           _log("Kanal: ${payloadMap['kanal'] ?? payloadMap['k']}");
           _log("Admin: ${payloadMap['admin']}");
           _log("MQTT: ${payloadMap['mqtt']}");
           _log("Lisans: ${payloadMap['lic']}");
           _log("Wifi: ${payloadMap['wifi']}");
           _log("AI: ${payloadMap['ai']}");
           _log("Sulama: ${payloadMap['sulama']}");
           _log("Aydınlatma: ${payloadMap['aydinlatma']}");
           _log("Uygulama Versiyonu: $appVersionString");
           _log("------------------------");
        }

        if (com != null) {
          _processSystemCommand(payloadMap, source, type, id, data);
        }
      }
      
      final decodedData = {
        'body': payload is Map ? (payload['txt'] ?? payload['message'] ?? payload.toString()) : payload.toString(),
        'id': id,
        'type': type,
        'source': source.name,
        'full_payload': payload,
        'timestamp': DateTime.now().toIso8601String(),
      };

      _dataController.add(decodedData);
    } catch (e) {
      debugPrint("Decode hatası ($source): $e");
    }
  }

  void _processSystemCommand(Map<String, dynamic> payload, TransmissionType source, String type, String id, Map<String, dynamic> rawData) {
    final String? com = payload['com'];
    
    if (com == 'room_intro' && payload.containsKey('room')) {
      final List rooms = payload['room'];
      _userManager.updateActiveUserRooms(rooms);
      _log("${rooms.length} adet oda alındı ve kaydedildi");
    } else if (com == 'grpintro' && payload.containsKey('grp')) {
      final List groups = payload['grp'];
      _userManager.updateActiveUserGroups(groups);
      _log("${groups.length} adet grup alındı ve kaydedildi");
    } else if (com == 'scnintro') {
      final List<dynamic>? scenes = payload['grp'] ?? payload['scn'];
      if (scenes != null) {
        _userManager.updateActiveUserScenes(scenes);
        _log("${scenes.length} adet senaryo alındı ve kaydedildi");
      }
    } else if (com == 'switch_intro') {
      final List<dynamic>? switches = payload['switch'] ?? payload['sw'];
      if (switches != null) {
        _userManager.updateActiveUserSwitches(switches);
        _log("${switches.length} adet anahtar alındı ve kaydedildi");
      }
    } else if (com == 'ins_intro' && payload.containsKey('scn')) {
      final List scn = payload['scn'];
      _userManager.updateActiveUserInsIntro(scn);
      _log("${scn.length} adet alt cihaz bilgisi alındı");
    } else if (com == 'intro' && payload.containsKey('gear')) {
      final List<dynamic> gear = payload['gear'];
      if (gear.isNotEmpty) {
        _userManager.updateActiveUserDevices(gear, channel: gear[0]['pr']);
        _log("${gear.length} adet cihaz bilgisi alındı");
      } else {
        // Gear boş ise kanal bilgisine göre temizle
        final int? kanal = int.tryParse(payload['kanal']?.toString() ?? '');
        if (kanal != null) {
          _userManager.clearDevicesByChannel(kanal);
          _log("Kanal $kanal cihaz listesi temizlendi");
        }
      }
    }
  }

  void send(dynamic message, {MessageOwner? receiver, Duration? timeout, bool forceUdp = false, bool forceMqtt = false}) {
    final user = _userManager.activeUser.value;
    if (user?.id == "demo_user_01") {
      _simulateDemoResponse(message);
      return;
    }

    final bool isLocal = _commServis.hasBoxConnection.value;
    
    if ((isLocal || forceUdp) && !forceMqtt) {
      if (receiver == null) {
        _udpService.sendBroadcast(message);
      } else {
        _udpService.sendUnicast(message, receiver, timeout: timeout);
      }
    } else {
      final deviceId = _userManager.activeUser.value?.deviceId;
      final SendTopic = "${_userManager.activeUser.value?.license}/in";
      if (deviceId != null && _mqttService.isConnected.value) {

        _mqttService.publish(SendTopic, {
          "pck": {"type": "UN", "id": "0"},
          "payload": message
        });
      }
    }
  }

  void _simulateDemoResponse(dynamic msg) {
    if (msg is Map) {
      final String? com = msg['com'];
      final int isGroup = msg['gurup'] ?? 0;

      if (com == 'arc_power' || com == 'off' || com == 'action' || com == 'go_scene') {
        int level = 0;
        if (com == 'arc_power') {
          level = msg['power'] ?? 0;
        } else if (com == 'off') {
          level = 0;
        } else if (com == 'action') {
          int actionKomut = msg['komut'] ?? 3;
          level = (actionKomut == 3) ? 254 : 0;
        } else if (com == 'go_scene') {
          level = 150; // Senaryo simülasyonu için orta seviye
        }

        Future.delayed(const Duration(milliseconds: 150), () {
          if (isGroup == 1 || (com == 'go_scene' && msg['adres'] == 255)) {
            // Grup veya Tümünü Etkileyen Senaryo: Tüm cihazları güncelle
            _bulkUpdateDemoDevices(level);
          } else {
            // Tekil Cihaz
            _handleIncomingMessage({
              "com": "status",
              "adres": msg['adres'] ?? msg['adr'],
              "kanal": msg['kanal'] ?? 1,
              "level": level,
              "is_passive_update": true
            }, TransmissionType.udp);
          }
        });
      } else if (com == 'voice') {
        final String txt = (msg['txt'] ?? "").toLowerCase();
        final String responseText = "Demo: Anlaşıldı, '${msg['txt']}' komutu işleniyor.";
        
        Future.delayed(const Duration(seconds: 1), () {
          _handleIncomingMessage({
            "com": "voice",
            "txt": responseText
          }, TransmissionType.udp);

          // Demo modunda sesli yanıt ver
          speak(responseText);

          // Sesli komutla cihaz durumlarını da değiştirelim (Simülasyon)
          if (txt.contains("kapat") || txt.contains("söndür")) {
            _bulkUpdateDemoDevices(0);
          } else if (txt.contains("aç") || txt.contains("yak")) {
            _bulkUpdateDemoDevices(254);
          }
        });
      } else if (com == 'get_mode') {
        _handleIncomingMessage({"com": "get_mode", "mode": 0, "alarm": 0}, TransmissionType.udp);
      } else if (com == 'get_irrigation') {
        _handleIncomingMessage({"com": "get_irrigation", "running": 0}, TransmissionType.udp);
      } else if (com == 'set_alarm') {
        final int? state = int.tryParse(msg['state']?.toString() ?? '');
        if (state != null) {
          Future.delayed(const Duration(milliseconds: 150), () {
            _handleIncomingMessage({"com": "set_alarm", "state": state}, TransmissionType.udp);
          });
        }
      } else if (com == 'set_mode') {
        final int? mode = int.tryParse(msg['mode']?.toString() ?? '');
        int? alarm = int.tryParse(msg['alarm']?.toString() ?? '');

        // Demo mantığı: Normal moda (0) geçişte alarmı kapat (0)
        if (mode == 0) {
          alarm = 0;
        }

        if (mode != null) {
          Future.delayed(const Duration(milliseconds: 150), () {
            Map<String, dynamic> response = {"com": "get_mode", "mode": mode};
            if (alarm != null) response["alarm"] = alarm;
            _handleIncomingMessage(response, TransmissionType.udp);
          });
        }
      }
    }
  }

  void _bulkUpdateDemoDevices(int level) {
    for (int i = 1; i <= 7; i++) {
      _handleIncomingMessage({
        "com": "status",
        "adres": i,
        "kanal": 1,
        "level": level,
        "is_passive_update": true
      }, TransmissionType.udp);
    }
  }

  void _log(String msg) {
    // Saat bilgisini kaldırdık, sadece mesajı iletiyoruz
    _logController.add(msg);
  }

  void dispose() {
    _dataController.close();
    _logController.close();
  }
}
