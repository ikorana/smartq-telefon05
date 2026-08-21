import 'dart:math';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:telefon05/screen/rootGate.dart';
import 'package:telefon05/theme/theme_service.dart';
import 'package:telefon05/translation/appTranslation.dart';
import 'package:telefon05/user/userManagementService.dart';

import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:telefon05/comminication/dataBridgeServis.dart';
import 'package:telefon05/utils/device_id_helper.dart';
import 'package:telefon05/utils/fcm_helper.dart';
import 'package:telefon05/utils/tts_helper.dart';
import 'package:telefon05/utils/stt_helper.dart';
import 'initialBinding.dart';

// Global reaktif ekran değişkenleri
final RxDouble scrWidth = 0.0.obs;
final RxDouble scrHeight = 0.0.obs;
final RxDouble scrInches = 0.0.obs;
final RxBool isTablet = false.obs;

final RxDouble btnIcoHigh = 55.0.obs;
final RxDouble btnTxtHigh = 35.0.obs;
final RxDouble btnHigh = (btnIcoHigh.value + btnTxtHigh.value).obs;

String appVersionString = '';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final packageInfo = await PackageInfo.fromPlatform();
  appVersionString = '${packageInfo.version}+${packageInfo.buildNumber}';

  // 1. GetStorage, TTS ve STT Başlatma (mikrofon/ses ikonlarının başlangıçta
  // gösterilip gösterilmeyeceğine karar vermek için burada, uygulama açılır
  // açılmaz kontrol ediyoruz)
  await GetStorage.init();
  initTTS();
  await checkTtsAvailability();
  await SttHelper.initialize();

  // 2. Firebase Başlatma
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Arka plan bildirim dinleyicisini kaydet
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 3. Ses Servisi Başlatma (Hata Yönetimli)
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.smartq.telefon05.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    debugPrint("Ses servisi başlatılamadı: $e");
  }

  // UUID İşlemleri
  final String deviceUuid = await DeviceIdHelper.getPersistentUUID();
  print("DEVICE UUID: $deviceUuid");

  // Ekran Ölçümleri
  _calculateScreenMetrics();

  // 4. Bildirim İzinleri
  try {
    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Kullanıcı bildirim izni verdi.');
      FcmHelper.init();
    }
  } catch (e) {
    print("Bildirim izni hatası: $e");
  }

  // 5. Temel Servisler
  Get.put(UserManagementService(), permanent: true);
  Get.put(ThemeService(), permanent: true);

  speak("Merhaba");

  runApp(const MyApp());
}

void _calculateScreenMetrics() {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  scrWidth.value = view.physicalSize.width / view.devicePixelRatio;
  scrHeight.value = view.physicalSize.height / view.devicePixelRatio;

  double diagonalLogical = sqrt(pow(scrWidth.value, 2) + pow(scrHeight.value, 2));
  scrInches.value = diagonalLogical / 160;

  double shortestSide = min(scrWidth.value, scrHeight.value);
  isTablet.value = shortestSide >= 600;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Get.find<ThemeService>();
    final userManager = Get.find<UserManagementService>();

    return Obx(() {
      return GetMaterialApp(
        title: 'Industrial Control System',
        debugShowCheckedModeBanner: false,
        initialBinding: InitialBinding(),
        initialRoute: '/root',
        translations: AppTranslations(),
        locale: Locale(userManager.activeLanguage.value),
        fallbackLocale: const Locale('en'),
        theme: themeService.allThemes[userManager.activeThemeIndex.value],
        themeMode: ThemeMode.light,
        getPages: [
          GetPage(
            name: '/root',
            page: () => const RootGate(),
            transition: Transition.fadeIn,
          ),
        ],
      );
    });
  }
}
