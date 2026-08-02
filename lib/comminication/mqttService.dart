import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:typed_data/typed_buffers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mqtt5_client/mqtt5_client.dart';
import 'package:mqtt5_client/mqtt5_server_client.dart';
import '../user/userManagementService.dart';

class MqttService extends GetxService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  MqttServerClient? _client;
  final _userManager = Get.find<UserManagementService>();
  
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  final RxBool isConnected = false.obs;
  String? _currentClientId;
  String? _currentIp;
  String? _lastAttemptedIp;
  String? _lastAttemptedClientId;

  @override
  void onInit() {
    super.onInit();
    
    // 1. ADIM: Aktif kullanıcı değiştikçe MQTT bağlantısını tazele
    ever(_userManager.activeUser, (user) {
      _handleUserChange(user);
    });

    // 2. ADIM: Başlangıçta halihazırda seçili bir kullanıcı varsa hemen bağlanmayı dene
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_userManager.activeUser.value != null) {
        debugPrint("--- [MQTT] Başlangıçta aktif kullanıcı bulundu, bağlanılıyor... ---");
        _handleUserChange(_userManager.activeUser.value);
      }
    });
  }

  void _handleUserChange(dynamic user) {
    if (user != null && 
        user.mqttIP != null && user.mqttIP!.isNotEmpty &&
        user.license != null && user.license!.isNotEmpty) {

      final newClientId = "${user.deviceId ?? user.name}_${DateTime.now().millisecondsSinceEpoch}";
      final newIp = user.mqttIP!;

      if (isConnected.value && _currentIp == newIp) {
        return;
      }

      if (!isConnected.value && _lastAttemptedIp == newIp && _lastAttemptedClientId != null) {
        return;
      }

      debugPrint("--- [MQTT] Bağlantı kriterleri sağlandı: $newIp ---");
      _setupClient(newIp, newClientId);
    } else {
      if (isConnected.value || _client != null) {
        debugPrint("--- [MQTT] Bilgiler eksik veya kullanıcı yok, bağlantı kesiliyor... ---");
        disconnect();
      }
    }
  }

  Future<void> _setupClient(String server, String clientId) async {
    if (isConnected.value) {
      disconnect();
    }
    
    _lastAttemptedIp = server;
    _lastAttemptedClientId = clientId;
    _currentClientId = clientId;
    _currentIp = server;

    // maxConnectionAttempts, constructor içinde belirtilmelidir çünkü final bir alandır.
    _client = MqttServerClient(server, clientId, maxConnectionAttempts: 5);
    _client!.port = 1883; 
    _client!.keepAlivePeriod = 20;
    
    // Temel Callbacks
    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.onSubscribed = _onSubscribed;
    
    // Reconnect Callbacks
    _client!.onAutoReconnect = _onAutoReconnect;
    _client!.onAutoReconnected = _onAutoReconnected;
    
    _client!.autoReconnect = true;
    _client!.logging(on: false);

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean(); 

    _client!.connectionMessage = connMess;

    try {
      debugPrint("--- [MQTT5] Bağlantı deneniyor: $server (Timeout: 3s) ---");
      // Future.timeout kullanarak 3 saniyelik bir zaman aşımı ekliyoruz
      await _client!.connect().timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint("--- [MQTT5] Bağlantı Hatası veya Zaman Aşımı: $e ---");
      _onDisconnected();
      _lastAttemptedIp = null;
      return; 
    }

    if (_client != null && _client!.connectionStatus?.state == MqttConnectionState.connected) {
      _client!.updates.listen((List<MqttReceivedMessage<MqttMessage>>? c) {
        if (c == null) return;
        final recMess = c[0].payload as MqttPublishMessage;
        final topic = c[0].topic;
        
        final payloadMessage = recMess.payload.message;
        if (payloadMessage != null) {
          final pt = MqttPublishPayload.bytesToStringAsString(payloadMessage);
          // Gelen mesaj logu kaldırıldı
          try {
            final Map<String, dynamic> data = jsonDecode(pt);
            _messageController.add(data);
          } catch (e) {
            debugPrint("--- [MQTT5] JSON Decode Hatası ($topic): $e ---");
          }
        }
      });
    }
  }

  void _onConnected() {
    isConnected.value = true;
    _lastAttemptedIp = null;
    _lastAttemptedClientId = null;
    debugPrint('--- [MQTT5] BAĞLANDI (Client: $_currentClientId) ---');
    
    final user = _userManager.activeUser.value;
    if (user != null && user.license != null) {
      // Cihazdan gelen bilgiler {lisans}/out topigine gelir
      final topic = "${user.license}/out";
      subscribe(topic);
    }
  }

  void _onDisconnected() {
    if (isConnected.value) {
      isConnected.value = false;
      debugPrint('--- [MQTT5] BAĞLANTI KESİLDİ ---');
    }
    _client = null;
  }

  void _onAutoReconnect() {
    debugPrint('--- [MQTT5] Bağlantı koptu, otomatik yeniden bağlanma deneniyor... ---');
    isConnected.value = false;
  }

  void _onAutoReconnected() {
    debugPrint('--- [MQTT5] Otomatik yeniden bağlanma BAŞARILI. ---');
    isConnected.value = true;
  }

  void _onSubscribed(MqttSubscription subscription) {
    debugPrint('--- [MQTT5] Abone Olundu: ${subscription.topic.rawTopic} ---');
  }

  void reconnect() {
    final user = _userManager.activeUser.value;
    if (user != null) {
      debugPrint("--- [MQTT5] Manuel yeniden bağlantı tetiklendi ---");
      _handleUserChange(user);
    }
  }

  void subscribe(String topic) {
    if (isConnected.value) {
      _client?.subscribe(topic, MqttQos.atLeastOnce);
    }
  }

  void publish(String topic, Map<String, dynamic> message) {
    if (isConnected.value) {
      final builder = MqttPayloadBuilder();
      final data = utf8.encode(jsonEncode(message));
      final buffer = Uint8Buffer();
      buffer.addAll(data);
      builder.addBuffer(buffer);
      _client?.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    }
  }

  void disconnect() {
    _client?.disconnect();
    _onDisconnected();
    _currentClientId = null;
    _currentIp = null;
  }

  @override
  void onClose() {
    disconnect();
    _messageController.close();
    super.onClose();
  }
}
