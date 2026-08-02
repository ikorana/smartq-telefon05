import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../user/userManagementService.dart';
import 'udp.dart';

enum DeviceType { tablet, phone, pc }

enum ConnectionStatus { connected, disconnected, wifiOnly, mobileData, connecting, none }

enum TransmissionType { udp, mqtt }

class ConnectionInfo {
  final ConnectionStatus status;
  final bool hasInternet;
  final bool hasBoxConnection;

  ConnectionInfo({
    required this.status, 
    required this.hasInternet,
    this.hasBoxConnection = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectionInfo &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          hasInternet == other.hasInternet &&
          hasBoxConnection == other.hasBoxConnection;

  @override
  int get hashCode => status.hashCode ^ hasInternet.hashCode ^ hasBoxConnection.hashCode;
}

class MessageOwner {
  final TransmissionType transmission;
  final String ip;
  final int port;

  MessageOwner({
    required this.transmission,
    required this.ip,
    required this.port,
  });

  Map<String, dynamic> toMap() {
    return {
      'transmission': transmission.name,
      'ip': ip,
      'port': port,
    };
  }
}

class ComminicationServis extends GetxService {
  static final ComminicationServis _instance = ComminicationServis._internal();
  factory ComminicationServis() => _instance;
  ComminicationServis._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription? _udpSubscription;
  Timer? _statusTimer;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  
  final _statusController = StreamController<ConnectionInfo>.broadcast();
  Stream<ConnectionInfo> get statusStream => _statusController.stream;

  final Rx<ConnectionInfo> rxConnectionStatus = ConnectionInfo(
    status: ConnectionStatus.none, 
    hasInternet: false,
    hasBoxConnection: false,
  ).obs;

  final RxBool hasBoxConnection = false.obs;
  final RxBool isSplashFinished = false.obs;

  DateTime? _lastBoxSeen;
  ConnectionStatus _lastStatus = ConnectionStatus.none;
  bool _lastInternet = false;
  bool _lastBoxConnection = false;

  @override
  void onInit() {
    super.onInit();
    init(DeviceType.phone);

    Future.delayed(const Duration(milliseconds: 2500), () {
      isSplashFinished.value = true;
    });
  }

  void init(DeviceType type) {
    final initialInfo = ConnectionInfo(status: ConnectionStatus.connecting, hasInternet: false, hasBoxConnection: false);
    _statusController.add(initialInfo);
    rxConnectionStatus.value = initialInfo;
    _startMonitoring();
  }

  void _startMonitoring() {
    _connectivitySubscription?.cancel();
    _udpSubscription?.cancel();
    _statusTimer?.cancel();
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    
    UdpService().init();

    _checkStatus();

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      await Future.delayed(const Duration(seconds: 1));
      _checkStatus(results: results);
      
      if (results.contains(ConnectivityResult.wifi) || results.contains(ConnectivityResult.ethernet)) {
        _reconnectUdp();
      }
    });

    _udpSubscription = UdpService().messages.listen((msg) {
      final activeUser = Get.find<UserManagementService>().activeUser.value;
      if (activeUser == null || (activeUser.deviceIp ?? '').isEmpty) return;
      
      if (msg['address'] == activeUser.deviceIp) {
        _lastBoxSeen = DateTime.now();
        if (!hasBoxConnection.value) {
          _updateBoxStatus(true);
        }
      }
    });

    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkStatus());
    _pingTimer = Timer.periodic(const Duration(seconds: 10), (_) => _sendPingToBox());
    _reconnectTimer = Timer.periodic(const Duration(seconds: 60), (_) => _reconnectUdp()); 
  }

  Future<void> _reconnectUdp() async {
    final status = await _connectivity.checkConnectivity();
    final activeUser = Get.find<UserManagementService>().activeUser.value;
    
    // Geçersiz kullanıcı durumunda çık
    if (activeUser == null || (activeUser.id ?? '').isEmpty || (activeUser.deviceIp ?? '').isEmpty) {
      return;
    }

    if ((status.contains(ConnectivityResult.wifi) || status.contains(ConnectivityResult.ethernet))) {
      if (!hasBoxConnection.value) {
        await UdpService().init();
        _sendPingToBox();
      }
    }
  }

  Future<void> _sendPingToBox() async {
    final activeUser = Get.find<UserManagementService>().activeUser.value;
    
    // ÇOK SIKI KONTROL: Kullanıcı nesnesi olsa bile ID, İsim veya IP boşsa ping atma
    if (activeUser == null || 
        (activeUser.id ?? '').isEmpty || 
        (activeUser.name ?? '').isEmpty || 
        (activeUser.deviceIp ?? '').isEmpty) {
      
      if (hasBoxConnection.value) {
        debugPrint("--- [COMM] Aktif kullanıcı/IP yok, bağlantı kesildi. ---");
        _updateBoxStatus(false);
      }
      return;
    }

    // Konsolda hangi IP'ye ping atıldığını görelim
    // debugPrint("--- [COMM] Ping gönderiliyor: ${activeUser.deviceIp} ---");

    UdpService().sendRawByte('P', activeUser.deviceIp!, 53250);

    if (_lastBoxSeen != null) {
      final difference = DateTime.now().difference(_lastBoxSeen!);
      if (difference > const Duration(seconds: 25)) {
        _updateBoxStatus(false);
      } else {
        _updateBoxStatus(true);
      }
    } else {
      _updateBoxStatus(false);
    }
  }

  void _updateBoxStatus(bool status) {
    if (hasBoxConnection.value != status) {
      hasBoxConnection.value = status;
      _checkStatus();
    }
  }

  Future<void> _checkStatus({List<ConnectivityResult>? results}) async {
    final connectivityResults = results ?? await _connectivity.checkConnectivity();
    
    bool hasInternet = false;
    ConnectionStatus currentStatus = ConnectionStatus.disconnected;

    try {
      if (connectivityResults.isNotEmpty && !connectivityResults.contains(ConnectivityResult.none)) {
        final lookupResult = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 2));
        hasInternet = lookupResult.isNotEmpty && lookupResult[0].rawAddress.isNotEmpty;
      }
    } catch (_) {
      hasInternet = false;
    }

    if (connectivityResults.contains(ConnectivityResult.wifi) || 
        connectivityResults.contains(ConnectivityResult.ethernet)) {
      currentStatus = ConnectionStatus.wifiOnly;
    } else if (connectivityResults.contains(ConnectivityResult.mobile)) {
      currentStatus = ConnectionStatus.mobileData;
    } else if (connectivityResults.isNotEmpty && connectivityResults.first != ConnectivityResult.none) {
      currentStatus = ConnectionStatus.connected;
    }

    final boxConn = hasBoxConnection.value;

    if (currentStatus != _lastStatus || hasInternet != _lastInternet || boxConn != _lastBoxConnection) {
      _lastStatus = currentStatus;
      _lastInternet = hasInternet;
      _lastBoxConnection = boxConn;
      
      final info = ConnectionInfo(status: currentStatus, hasInternet: hasInternet, hasBoxConnection: boxConn);
      _statusController.add(info);
      rxConnectionStatus.value = info;
    }
  }

  void stop() {
    _connectivitySubscription?.cancel();
    _udpSubscription?.cancel();
    _statusTimer?.cancel();
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _statusController.close();
  }

  @override
  void onClose() {
    stop();
    super.onClose();
  }
}
