import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../comminication/dataBridgeServis.dart';
import '../user/userManagementService.dart';
import 'device_id_helper.dart';
import 'tts_helper.dart';

class FcmHelper {
  static final _storage = GetStorage();
  static const _lastTokenKey = 'last_registered_fcm_token';
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  /// FCM ve Bildirim sistemini başlatır
  static Future<void> init() async {
    await _initLocalNotifications();
    
    // Uygulama ön plandayken bildirim gelirse
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("SİSTEM: Ön planda bildirim alındı: ${message.notification?.title}");
      _handleIncomingMessage(message);
    });

    // Uygulama arka planda kapalıyken bildirime tıklanarak açılırsa
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("SİSTEM: Bildirime tıklanarak uygulama açıldı");
      // Gerekli yönlendirmeler burada yapılabilir
    });

    // Token işlemlerini başlat
    setupFcmToken();
  }

  /// Yerel bildirim ayarlarını yapar (Ön planda gösterim için)
  static Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        print("SİSTEM: Yerel bildirime tıklandı");
      },
    );
  }

  /// Gelen FCM mesajını işler
  static void _handleIncomingMessage(RemoteMessage message) {
    // 1. Eğer veri içinde 'say' komutu varsa seslendir
    if (message.data.containsKey('com') && message.data['com'] == 'say') {
      final String text = message.data['txt'] ?? "";
      speak(text);
    }

    // 2. Ön plandaysa görsel bildirimi biz tetiklemeliyiz (Android için şart)
    if (message.notification != null) {
      _showLocalNotification(message);
    }
  }

  /// Yerel bildirim gösterir
  static void _showLocalNotification(RemoteMessage message) {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'alarm_channel', // Cloud function'daki channelId ile aynı olmalı
      'Sistem Alarmları',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    );

    _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      platformDetails,
    );
  }

  /// FCM Token alımı ve Firebase kaydı
  static Future<void> setupFcmToken() async {
    // Token yenileme dinleyicisi
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      saveTokenToFirebase(newToken);
    });

    try {
      // iOS'ta APNS token'ın gelmesi biraz zaman alabilir
      if (Platform.isIOS) {
        for (int i = 0; i < 5; i++) {
          String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          if (apnsToken != null) break;
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        print("---------------- FCM TOKEN ----------------");
        print(token);
        print("-------------------------------------------");
        saveTokenToFirebase(token);
      }
    } catch (e) {
      print("FCM Token alımı başarısız: $e");
    }
  }

  /// Token ve cihaz bilgilerini Firebase Cloud Function üzerinden Firestore'a kaydeder
  static Future<void> saveTokenToFirebase([String? token]) async {
    try {
      String? currentToken = token ?? await FirebaseMessaging.instance.getToken();
      if (currentToken == null) return;

      // Token değişmiş mi kontrol et
      final String? lastToken = _storage.read<String>(_lastTokenKey);
      if (lastToken == currentToken) {
        print("SİSTEM: FCM Token değişmediği için Firebase kaydı atlandı.");
        return;
      }

      final String uuid = await DeviceIdHelper.getPersistentUUID();
      final userManager = Get.find<UserManagementService>();
      final String? license = userManager.activeUser.value?.license;

      if (license == null || license.isEmpty) {
        print("SİSTEM: Lisans bilgisi bulunamadığı için Firebase kaydı atlandı.");
        return;
      }

      final url = Uri.parse('https://us-central1-telefon05.cloudfunctions.net/kaydetCihazToken');
      
      final body = jsonEncode({
        "data": {
          "cihazId": uuid,
          "platform": Platform.operatingSystem,
          "fcmToken": currentToken,
          "license": license
        }
      });

      print("SİSTEM: Firebase'e giden paket: $body");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        print("SİSTEM: Cihaz ve FCM token başarıyla Firebase'e kaydedildi.");
        _storage.write(_lastTokenKey, currentToken);
      } else {
        print("SİSTEM: Firebase kaydı başarısız. Status: ${response.statusCode}, Body: ${response.body}");
      }
    } catch (e) {
      print("SİSTEM: Firebase token kaydı sırasında hata: $e");
    }
  }
}

/// Arka planda gelen mesajları karşılar (Global olmalı)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Arka planda seslendirme kısıtlıdır ama veriyi loglayabiliriz
  print("SİSTEM: Arka planda bildirim alındı: ${message.messageId}");
}
