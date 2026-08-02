import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'comminication.dart';

class PendingMessage {
  final String id;
  final dynamic message;
  final MessageOwner? receiver;
  final Duration timeout;
  int retryCount = 0;
  Timer? timer;

  PendingMessage({
    required this.id, 
    required this.message, 
    this.receiver,
    required this.timeout,
  });
}

class UdpService {
  static final UdpService _instance = UdpService._internal();
  factory UdpService() => _instance;
  UdpService._internal();

  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _socketSubscription;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  List<String> _myIps = [];
  int _currentPort = 53250; 
  Duration _defaultTimeout = const Duration(seconds: 5);
  
  final Map<String, PendingMessage> _pendingAcks = {};
  int _lastId = 0; 
  Completer<void>? _initCompleter;
  
  final Map<String, String> _receiveBuffers = {};
  bool _isReconnecting = false;
  Timer? _reconnectTimer;

  Stream<Map<String, dynamic>> get messages => _controller.stream;

  Future<void> init({int port = 53250, Duration timeout = const Duration(seconds: 5), bool force = false}) async {
    if (_initCompleter != null) return _initCompleter!.future;
    
    // Eğer soket zaten aktifse ve zorlanmıyorsa işlemi atla
    if (!force && _socket != null && _currentPort == port) return;

    _initCompleter = Completer<void>();
    _currentPort = port;
    _defaultTimeout = timeout;
    
    try {
      await _cleanup();

      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port, reuseAddress: true, reusePort: true);
      _socket?.broadcastEnabled = true;
      
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      _myIps = interfaces.expand((i) => i.addresses).map((a) => a.address).toList();

      _socketSubscription = _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          Datagram? dg;
          while ((dg = _socket?.receive()) != null) {
            if (dg != null) {
              if (_myIps.contains(dg.address.address)) continue;
              _handleRawIncoming(dg);
            }
          }
        }
      }, 
      onError: (err) {
        print("--- [UDP] Soket Listen Hatası: $err ---");
        _handleSocketFailure();
      },
      onDone: () {
        print("--- [UDP] Soket Kapandı (onDone) ---");
        _handleSocketFailure();
      });

      print("--- [UDP] Soket Başlatıldı. Port: $_currentPort ---");
      _isReconnecting = false;
      _reconnectTimer?.cancel();
      _initCompleter!.complete();
    } catch (e) {
      print('--- [UDP] Init Hatası: $e ---');
      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        _initCompleter!.completeError(e);
      }
      _handleSocketFailure(); 
    } finally {
      _initCompleter = null;
    }
  }

  void _handleSocketFailure() {
    if (_isReconnecting) return;
    _isReconnecting = true;
    
    _cleanup();
    
    print("--- [UDP] Bağlantı koptu. 3 saniye içinde yeniden bağlanmayı deneyecek... ---");
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _isReconnecting = false;
      init(port: _currentPort, force: true);
    });
  }

  Future<void> _cleanup() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket?.close();
    _socket = null;
    _receiveBuffers.clear();
    // Soketin kapanması için kısa bir bekleme
    await Future.delayed(const Duration(milliseconds: 50));
  }

  void _handleRawIncoming(Datagram dg) {
    try {
      String incomingFragment = utf8.decode(dg.data, allowMalformed: true).replaceAll('\u0000', '');
      String ip = dg.address.address;
      
      if (dg.data.length == 1) {
        String code = String.fromCharCode(dg.data[0]);
        if (code == 'P') { 
          sendRawByte('O', dg.address.address, dg.port);
          return;
        }
        if (code == 'O') {
          _controller.add({
            'type': 'PONG', 
            'address': dg.address.address, 
            'id': '0',
            'full_payload': {'com': 'pong'}
          });
          return;
        }
      }

      _receiveBuffers[ip] = (_receiveBuffers[ip] ?? "") + incomingFragment;

      if (_receiveBuffers[ip]!.contains('&')) {
        List<String> parts = _receiveBuffers[ip]!.split('&');
        _receiveBuffers[ip] = parts.removeLast();

        for (String completeMessage in parts) {
          if (completeMessage.trim().isNotEmpty) {
            _processJsonPacket(completeMessage.trim(), ip, dg.port);
          }
        }
      } 
      else if (incomingFragment.trim().startsWith('{') && incomingFragment.trim().endsWith('}')) {
         _processJsonPacket(incomingFragment.trim(), ip, dg.port);
         _receiveBuffers[ip] = ""; 
      }
    } catch (e) {
      print("--- [UDP] Gelen veri işleme hatası: $e ---");
    }
  }

  void _processJsonPacket(String rawJson, String address, int port) {
    try {
      Map<String, dynamic> data = jsonDecode(rawJson);
      
      String type = 'RAW';
      String id = '0';
      dynamic payload = data;
      Map<String, dynamic>? originalPayload;

      if (data.containsKey('pck') && data.containsKey('payload')) {
        type = data['pck']['type']?.toString() ?? 'RAW';
        id = data['pck']['id']?.toString().trim() ?? '0';
        payload = data['payload'];
      }

      if (type == 'AK') {
        if (_pendingAcks.containsKey(id)) {
          final pending = _pendingAcks[id];
          pending?.timer?.cancel();
          if (pending?.message is Map) {
            originalPayload = pending!.message;
          }
          _pendingAcks.remove(id);
        }
      } else if (type == 'UN' && id != '0') {
        final owner = MessageOwner(transmission: TransmissionType.udp, ip: address, port: port);
        _sendRawJson('AK', id, {}, owner);
      }

      _controller.add({
        'type': type,
        'id': id,
        'address': address,
        'port': port,
        'full_payload': payload,
        'original_request': originalPayload,
      });
      
    } catch (e) {
      print("--- [UDP] Parse Hatası: $e | JSON: $rawJson ---");
    }
  }

  Future<void> sendUnicast(dynamic message, MessageOwner owner, {Duration? timeout}) async {
    if (_socket == null) await init();
    String id = _generateShortId();
    _pendingAcks[id] = PendingMessage(id: id, message: message, receiver: owner, timeout: timeout ?? _defaultTimeout);
    _attemptSend(id);
  }

  Future<void> sendBroadcast(dynamic message) async {
    if (_socket == null) await init();
    String id = _generateShortId();
    
    _pendingAcks[id] = PendingMessage(id: id, message: message, timeout: const Duration(seconds: 10));
    Timer(const Duration(seconds: 10), () => _pendingAcks.remove(id));

    Map<String, dynamic> packet = {"pck": {"type": "BR", "id": id}, "payload": message};
    String jsonStr = jsonEncode(packet) + "&";
    final data = utf8.encode(jsonStr);

    try {
      final interfaces = await NetworkInterface.list(includeLoopback: false, type: InternetAddressType.IPv4);
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.address == "127.0.0.1") continue;
          
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            final broadcast = "${parts[0]}.${parts[1]}.${parts[2]}.255";
            _socket?.send(data, InternetAddress(broadcast), _currentPort);
          }
        }
      }
    } catch (e) {
      print("--- [UDP] Broadcast Gönderim Hatası: $e ---");
      _handleSocketFailure();
    }
  }

  void _attemptSend(String id) {
    final pending = _pendingAcks[id];
    if (pending == null || pending.receiver == null) return;
    if (pending.retryCount >= 3) { 
      _pendingAcks.remove(id); 
      return; 
    }
    _sendRawJson('UN', id, pending.message, pending.receiver!);
    pending.retryCount++;
    pending.timer?.cancel();
    pending.timer = Timer(pending.timeout, () => _attemptSend(id));
  }

  void _sendRawJson(String type, String id, dynamic payload, MessageOwner owner) {
    if (_socket == null) {
      init(force: true).then((_) => _sendRawJson(type, id, payload, owner));
      return;
    }
    try {
      Map<String, dynamic> packet = {"pck": {"type": type, "id": id}, "payload": payload};
      String jsonStr = jsonEncode(packet) + "&";
      _socket?.send(utf8.encode(jsonStr), InternetAddress(owner.ip), owner.port);
    } catch (e) {
      print("--- [UDP] JSON Gönderim Hatası: $e ---");
      _handleSocketFailure();
    }
  }

  void sendRawByte(String char, String ip, int port) {
    if (_socket == null) {
      init(force: true).then((_) => sendRawByte(char, ip, port));
      return;
    }
    try {
      _socket?.send(char.codeUnits, InternetAddress(ip), port);
    } catch (e) {
      print("--- [UDP] Byte Gönderim Hatası: $e ---");
      _handleSocketFailure();
    }
  }

  String _generateShortId() {
    _lastId = (_lastId + 1) % 999;
    return _lastId.toString();
  }

  void dispose() {
    for (var p in _pendingAcks.values) { p.timer?.cancel(); }
    _reconnectTimer?.cancel();
    _socketSubscription?.cancel();
    _socket?.close();
    _socket = null;
    _controller.close();
  }
}
