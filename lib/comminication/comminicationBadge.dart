import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'comminication.dart';
import 'mqttService.dart';
import '../utils/device_id_helper.dart';
import '../utils/fcm_helper.dart';
import '../main.dart';

class ComminicationBadge extends StatefulWidget {
  const ComminicationBadge({super.key});

  @override
  State<ComminicationBadge> createState() => _ComminicationBadgeState();
}

class _ComminicationBadgeState extends State<ComminicationBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showConnectionDetails(BuildContext context, ComminicationServis commServis) async {
    final info = commServis.rxConnectionStatus.value;
    final mqttConnected = Get.find<MqttService>().isConnected.value;
    final theme = Theme.of(context);
    final String uuid = await DeviceIdHelper.getPersistentUUID();

    // Popup açıldığında token bilgisini Firebase'e kaydet
    FcmHelper.saveTokenToFirebase();

    Get.dialog(
      Dialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'network_status'.tr,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Icon(Icons.close, size: 24, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1),
              ),
              _buildDetailRow(
                Icons.fingerprint,
                'Device UUID',
                uuid.length > 15 ? '${uuid.substring(0, 8)}...${uuid.substring(uuid.length - 4)}' : uuid,
                theme.colorScheme.primary,
                onLongPress: () {
                  // UUID'yi panoya kopyalama özelliği eklenebilir
                  Get.snackbar("Kopyalandı", "UUID panoya kopyalandı", snackPosition: SnackPosition.BOTTOM);
                },
              ),
              _buildDetailRow(
                Icons.router,
                'Bağlantı Tipi',
                info.hasBoxConnection ? 'Yerel (UDP)' : (mqttConnected ? 'Bulut (MQTT)' : 'Bağlantı Yok'),
                info.hasBoxConnection || mqttConnected ? Colors.green : Colors.red,
              ),
              _buildDetailRow(
                info.status == ConnectionStatus.wifiOnly ? Icons.wifi : Icons.signal_cellular_alt,
                'Transmisyon',
                info.status == ConnectionStatus.wifiOnly ? 'Wi-Fi' : (info.status == ConnectionStatus.mobileData ? 'Mobil Veri' : 'Bağlı Değil'),
                info.status != ConnectionStatus.disconnected ? Colors.blue : Colors.red,
              ),
              _buildDetailRow(
                Icons.public,
                'İnternet Erişimi',
                info.hasInternet ? 'Mevcut' : 'Yok',
                info.hasInternet ? Colors.green : Colors.orange,
              ),
              _buildDetailRow(
                Icons.cloud_outlined,
                'MQTT Durumu',
                mqttConnected ? 'Bağlı' : 'Bağlı Değil',
                mqttConnected ? Colors.green : Colors.grey,
              ),
              _buildDetailRow(
                Icons.info_outline,
                'Uygulama Versiyonu',
                appVersionString,
                theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color statusColor, {VoidCallback? onLongPress}) {
    return InkWell(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(icon, size: 22, color: statusColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            Text(
              value,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final commServis = Get.find<ComminicationServis>();
    
    return Obx(() {
      final info = commServis.rxConnectionStatus.value;
      final status = info.status;
      final hasInternet = info.hasInternet;
      final hasBox = info.hasBoxConnection;

      final isConnecting = status == ConnectionStatus.connecting;

      if (isConnecting) {
        if (!_controller.isAnimating) {
          _controller.repeat(reverse: true);
        }
      } else {
        if (_controller.isAnimating) {
          _controller.stop();
        }
      }

      return GestureDetector(
        onTap: () => _showConnectionDetails(context, commServis),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.scale(
                  scale: isConnecting ? _animation.value : 1.0,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getBadgeColor(status).withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getBadgeColor(status),
                        width: 2,
                      ),
                      boxShadow: isConnecting
                          ? [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.3),
                                blurRadius: 10 * _animation.value,
                                spreadRadius: 2 * _animation.value,
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Icon(
                        _getStatusIcon(status),
                        color: _getBadgeColor(status),
                        size: 22,
                      ),
                    ),
                  ),
                );
              },
            ),
            // Ana kutu bağlantısı (Sol alt)
            Positioned(
              left: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Icon(
                  Icons.router,
                  color: hasBox ? Colors.green : Colors.red,
                  size: 14,
                ),
              ),
            ),
            // İnternet bağlantısı (Sağ alt)
            if (hasInternet)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 2,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                child: const Icon(
                  Icons.public,
                  color: Colors.green,
                  size: 14,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Color _getBadgeColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.wifiOnly:
      case ConnectionStatus.mobileData:
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.connecting:
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.wifiOnly:
        return Icons.wifi;
      case ConnectionStatus.mobileData:
        return Icons.phone_android;
      case ConnectionStatus.connected:
        return Icons.wifi;
      case ConnectionStatus.connecting:
        return Icons.sync;
      default:
        return Icons.wifi_off;
    }
  }
}
