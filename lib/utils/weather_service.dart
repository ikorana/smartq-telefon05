import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';

import '../comminication/comminication.dart';
import '../comminication/dataBridgeServis.dart';
import '../user/userManagementService.dart';

class WeatherData {
  final double temp;
  final String condition;
  final String icon;
  final String city;
  final double rain3h;
  final double lat;
  final double lon;
  final DateTime timestamp;

  WeatherData({
    required this.temp,
    required this.condition,
    required this.icon,
    required this.city,
    required this.rain3h,
    required this.lat,
    required this.lon,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'temp': temp,
    'condition': condition,
    'icon': icon,
    'city': city,
    'rain3h': rain3h,
    'lat': lat,
    'lon': lon,
    'timestamp': timestamp.toIso8601String(),
  };

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
    temp: (json['temp'] as num).toDouble(),
    condition: json['condition'],
    icon: json['icon'],
    city: json['city'],
    rain3h: (json['rain3h'] as num? ?? 0.0).toDouble(),
    lat: (json['lat'] as num? ?? 0.0).toDouble(),
    lon: (json['lon'] as num? ?? 0.0).toDouble(),
    timestamp: DateTime.parse(json['timestamp']),
  );
}

class WeatherService extends GetxService {
  static const String _apiKey = "YOUR_API_KEY_HERE";
  final _storage = GetStorage();
  final Rxn<WeatherData> currentWeather = Rxn<WeatherData>();
  Timer? _scheduleTimer;

  @override
  void onInit() {
    super.onInit();
    _loadSavedWeather();
    fetchWeather(); // Initial fetch on startup
    _setupScheduling();
  }

  void _loadSavedWeather() {
    final saved = _storage.read('last_weather');
    if (saved != null) {
      currentWeather.value = WeatherData.fromJson(saved);
    }
  }

  Future<void> fetchWeather() async {
    try {
      Position position = await _determinePosition();

      
      debugPrint("KONUM ALINDI: Lat: ${position.latitude}, Lon: ${position.longitude}");

      final url = Uri.parse(
          "https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$_apiKey&units=metric&lang=tr");

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        double rainVal = 0.0;
        if (data.containsKey('rain')) {
          if (data['rain'].containsKey('3h')) {
            rainVal = (data['rain']['3h'] as num).toDouble();
          } else if (data['rain'].containsKey('1h')) {
            // Eğer 3 saatlik veri yoksa 1 saatliği de kabul edebiliriz 
            // veya doğrudan 3h odaklı kalabiliriz.
            rainVal = (data['rain']['1h'] as num).toDouble();
          }
        }

        final weather = WeatherData(
          temp: (data['main']['temp'] as num).toDouble(),
          condition: data['weather'][0]['description'],
          icon: data['weather'][0]['icon'],
          city: data['name'],
          rain3h: rainVal,
          lat: position.latitude,
          lon: position.longitude,
          timestamp: DateTime.now(),
        );

        currentWeather.value = weather;
        _storage.write('last_weather', weather.toJson());
        
        // Ana cihaza hava durumunu bildir
        _sendWeatherToGateway(weather);

        debugPrint("HAVA DURUMU GÜNCELLENDİ: ${weather.city}, ${weather.temp}°C, Yağış (3h): ${weather.rain3h}mm");
      }
    } catch (e) {
      debugPrint("Hava durumu çekme hatası: $e");
    }
  }

  void _sendWeatherToGateway(WeatherData weather) {
    try {
      if (Get.isRegistered<DataBridgeService>() && Get.isRegistered<UserManagementService>()) {
        final dataBridge = Get.find<DataBridgeService>();
        final userManager = Get.find<UserManagementService>();
        final user = userManager.activeUser.value;

        // Hedef alıcıyı (Gateway) belirle
        MessageOwner? receiver;
        if (user?.deviceIp != null && user!.deviceIp!.isNotEmpty) {
          receiver = MessageOwner(
            transmission: TransmissionType.udp,
            ip: user.deviceIp!,
            port: 53250,
          );
        }

        dataBridge.send({
          "com": "weather",
          "city": weather.city,
          "temp": weather.temp,
          "condition": weather.condition,
          "rain3h": weather.rain3h,
          "lat": weather.lat,
          "lon": weather.lon,
        }, receiver: receiver); // Hedef belirlenmişse Unicast, yoksa Broadcast gider

        debugPrint("SİSTEM: Hava durumu bilgisi ${receiver != null ? 'Unicast (${receiver.ip})' : 'Broadcast'} olarak Gateway'e gönderildi.");
      }
    } catch (e) {
      debugPrint("Gateway'e hava durumu gönderme hatası: $e");
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Konum servisleri kapalı.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Konum izni reddedildi.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Konum izinleri kalıcı olarak reddedildi.');
    }

    // Daha hızlı ve doğru sonuç için son bilinen konumu kontrol et
    Position? lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) {
      // Eğer son bilinen konum 30 dakikadan yeniyse onu kullanabiliriz
      // Ancak OpenWeatherMap için taze veri her zaman iyidir.
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high, // Daha yüksek doğruluk için high
      timeLimit: const Duration(seconds: 10),
    );
  }

  void _setupScheduling() {
    _scheduleTimer?.cancel();
    _checkAndScheduleNext();
  }

  void _checkAndScheduleNext() {
    final now = DateTime.now();
    
    // Hedef saatler: 08:00, 12:00, 18:00
    final times = [8, 12, 18];
    DateTime? nextFetch;

    for (var hour in times) {
      final candidate = DateTime(now.year, now.month, now.day, hour);
      if (candidate.isAfter(now)) {
        nextFetch = candidate;
        break;
      }
    }

    // Eğer bugün için başka zaman kalmadıysa yarın sabah 08:00
    nextFetch ??= DateTime(now.year, now.month, now.day + 1, 8);

    final duration = nextFetch.difference(now);
    debugPrint("BİR SONRAKİ HAVA DURUMU GÜNCELLEMESİ: $nextFetch (Kalan: ${duration.inMinutes} dk)");

    _scheduleTimer = Timer(duration, () {
      fetchWeather();
      _checkAndScheduleNext(); // Bir sonrakini planla
    });
  }

  @override
  void onClose() {
    _scheduleTimer?.cancel();
    super.onClose();
  }
}
