import 'package:get/get.dart';

import 'comminication/comminication.dart';
import 'comminication/dataBridgeServis.dart';
import 'comminication/mqttService.dart';
import 'comminication/udp.dart';
import 'comminication/radioController.dart';
import 'utils/irrigation_service.dart';
import 'utils/weather_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // 1. Temel Servisler
    Get.put(ComminicationServis(), permanent: true);
    Get.put(IrrigationService(), permanent: true);
    Get.put(RadioController(), permanent: true);
    Get.put(WeatherService(), permanent: true);
    
    // 2. UDP Servisini Başlat ve Soketi Bağla
    final udp = Get.put(UdpService(), permanent: true);
    udp.init();

    // 3. MQTT Servisini Başlat
    Get.put(MqttService(), permanent: true);

    // 4. Karar ve Dağıtım katmanı
    Get.put(DataBridgeService(), permanent: true);
  }
}
