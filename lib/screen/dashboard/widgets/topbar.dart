import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../comminication/comminicationBadge.dart';
import '../../../user/userManagementService.dart';
import '../../../comminication/radioController.dart';
import '../../../utils/tts_helper.dart';
import '../../../utils/weather_service.dart';
import '../dashboardController.dart';
import 'rotating_refresh_icon.dart';

class DashboardTopbar extends StatelessWidget {
  const DashboardTopbar({super.key});

  @override
  Widget build(BuildContext context) {
    final userManager = Get.find<UserManagementService>();
    final controller = Get.find<DashboardController>();
    final radioController = Get.find<RadioController>();
    final weatherService = Get.find<WeatherService>();
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        bottom: 10,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. SATIR: Hoşgeldiniz ve Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'welcome'.tr,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Obx(() => Text(
                    userManager.activeUser.value?.name ?? '',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  )),
                ],
              ),
              Row(
                children: [
                  Obx(() {
                    if (!isTtsAvailable.value) return const SizedBox.shrink();
                    return IconButton(
                      icon: Icon(
                        radioController.isPlaying.value ? Icons.radio : Icons.radio_outlined,
                        color: radioController.isPlaying.value ? Colors.blue : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      onPressed: () => radioController.togglePlay(),
                      onLongPress: () => radioController.showRadioDialog(),
                    );
                  }),
                  Obx(() {
                    final weather = weatherService.currentWeather.value;
                    final bool isActive = controller.hasIrrigationModule.value;
                    return IconButton(
                      icon: Icon(
                        Icons.cloud_outlined,
                        color: isActive && weather != null ? Colors.orangeAccent : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      onPressed: isActive ? () => _showWeatherDialog(context, weatherService) : null,
                    );
                  }),
                  Obx(() {
                    if (!isTtsAvailable.value) return const SizedBox.shrink();
                    return IconButton(
                      icon: Icon(
                        isSoundEnabled.value ? Icons.volume_up : Icons.volume_off,
                        color: isSoundEnabled.value ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      onPressed: () => toggleSound(),
                    );
                  }),
                  const ComminicationBadge(),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          // 2. SATIR: Grup, Odalar Butonu + Getir İkonu, Senaryo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Sol: Grup -> DashboardContent içindeki Gruplar sayfasını açar
              _buildTopBarAction(
                context,
                Icons.groups_outlined,
                'groups'.tr,
                () => controller.changeIndex(1),
              ),
              
              // Orta: Odalar Seçim Butonu ve Bitişik Getir İkonu
              Obx(() => Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Oda Seçim Kısmı
                    InkWell(
                      onTap: () {
                        controller.changeIndex(4); // Cihazlar görünümüne geç
                        _showRoomsPopup(context, userManager, controller);
                      },
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.meeting_room_outlined, size: 18, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              controller.currentRoomName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.keyboard_arrow_down, size: 18, color: theme.colorScheme.primary),
                          ],
                        ),
                      ),
                    ),
                    // Dikey Ayırıcı
                    Container(
                      width: 1,
                      height: 20,
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                    // Getir İkonu (Refresh)
                    InkWell(
                      onTap: controller.isRefreshing.value 
                        ? null 
                        : () {
                            controller.changeIndex(4); // Cihazlar görünümüne geç
                            controller.sendRefreshCommand(); // Bilgileri tazele
                          },
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                        child: controller.isRefreshing.value
                          ? RotatingRefreshIcon(size: 18, color: theme.colorScheme.primary)
                          : Icon(Icons.refresh, size: 18, color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              )),

              // Sağ: Senaryo -> DashboardContent içindeki Senaryolar sayfasını açar
              _buildTopBarAction(
                context,
                Icons.auto_awesome_outlined,
                'scenarios'.tr,
                () => controller.changeIndex(2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarAction(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.onSurface.withValues(alpha: 0.7), size: 24),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showRoomsPopup(BuildContext context, UserManagementService userManager, DashboardController controller) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'rooms'.tr,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Kayıtlı Odalar
                      ...userManager.activeRooms.map((room) {
                        return _buildRoomItem(context, room.id, "${room.id} - ${room.name}", controller);
                      }),
                      const Divider(),
                      // Tüm Odalar Seçeneği (Sona alındı)
                      _buildRoomItem(context, null, 'all_rooms'.tr, controller),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomItem(BuildContext context, int? id, String name, DashboardController controller) {
    final isSelected = controller.selectedRoomId.value == id;
    final theme = Theme.of(context);

    return ListTile(
      onTap: () {
        controller.changeIndex(4); // Cihazlar görünümüne geç
        controller.setRoomFilter(id);
        Get.back();
      },
      title: Text(
        name,
        style: TextStyle(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check_circle, color: theme.colorScheme.primary) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  void _showWeatherDialog(BuildContext context, WeatherService weatherService) {
    final theme = Theme.of(context);
    final weather = weatherService.currentWeather.value;

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.wb_sunny_outlined, color: Colors.orangeAccent),
            const SizedBox(width: 10),
            Text('Hava Durumu'),
          ],
        ),
        content: weather == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  const Text("Hava durumu bilgisi yükleniyor..."),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    weather.city,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.network(
                        "https://openweathermap.org/img/wn/${weather.icon}@2x.png",
                        width: 80,
                        height: 80,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.cloud, size: 50),
                      ),
                      Text(
                        "${weather.temp.toInt()}°C",
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w300),
                      ),
                    ],
                  ),
                  Text(
                    weather.condition.capitalizeFirst!,
                    style: TextStyle(
                      fontSize: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          weather.rain3h > 0 ? Icons.umbrella : Icons.beach_access_outlined,
                          size: 16, 
                          color: Colors.blue
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Son 3 Saatlik Yağış: ${weather.rain3h.toStringAsFixed(1)} mm",
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Son Güncelleme: ${weather.timestamp.hour.toString().padLeft(2, '0')}:${weather.timestamp.minute.toString().padLeft(2, '0')}",
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () {
              weatherService.fetchWeather();
              Get.back();
            },
            child: const Text("YENİLE"),
          ),
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("KAPAT"),
          ),
        ],
      ),
    );
  }
}
