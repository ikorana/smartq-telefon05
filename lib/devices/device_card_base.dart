import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:telefon05/theme/app_colors.dart';
import 'package:telefon05/screen/dashboard/dashboardController.dart';
import 'package:telefon05/main.dart';

class DeviceCardBase extends StatelessWidget {
  final String name;
  final int id;
  final int? roomId;
  final int? channel;
  final bool isOn;
  final bool isBlocked;
  final bool isRefreshing;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Widget icon;
  final double? width;
  final RxDouble? height;
  final RxDouble? iconHeight;

  const DeviceCardBase({
    super.key,
    required this.name,
    required this.id,
    this.roomId,
    this.channel,
    required this.isOn,
    required this.isBlocked,
    required this.isRefreshing,
    required this.onTap,
    required this.onLongPress,
    required this.icon,
    this.width = 150,
    this.height,
    this.iconHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Get.theme;
    final controller = Get.find<DashboardController>();

    return Obx(() {
      final bool isAllRooms = controller.selectedRoomId.value == null;
      final bool hasRoom = roomId != null && roomId != 255;
      final bool isWifi = channel == 0;

      final appColors = theme.extension<AppColors>();
      Color borderColor = Colors.grey.withOpacity(0.3);
      Color cardBackgroundColor = appColors?.deviceBackground ?? Colors.white10;
      double borderWidth = 1.0;
      List<BoxShadow> shadows = [];

      if (isRefreshing) {
        borderColor = theme.colorScheme.primary;
        borderWidth = 2.0;
        shadows.add(
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.4),
            blurRadius: 10,
            spreadRadius: 2,
          )
        );
      } else if (isBlocked) {
        borderColor = Colors.blue.withOpacity(0.5);
        borderWidth = 1.5;
      } else if (isOn) {
        borderColor = theme.colorScheme.primary.withOpacity(0.7);
        borderWidth = 1.5;
      }

      // Ölçülendirme Mantığı (Birim Sistemi)
      double baseUnitWidth = 150.0;
      double cardMargin = 8.0; // 4px + 4px horizontal margin
      double wrapSpacing = 5.0; // Wrap widget'tan gelen spacing
      
      // Cihaz tipine göre birim genişliğini belirle
      // Telefon için: (Ekran - DashboardPadding(20) - KartMarginleri(24) - WrapSpacingleri(10)) / 3
      double currentUnitWidth = isTablet.value 
          ? baseUnitWidth 
          : (scrWidth.value > 0 ? (scrWidth.value - 20 - (3 * cardMargin) - (2 * wrapSpacing)) / 3 : baseUnitWidth);
      
      // Giriş genişliğini birime çevir (Örn: 300px -> 2 birim)
      double units = (width ?? baseUnitWidth) / baseUnitWidth;
      
      // Nihai Genişlik = (Birim Sayısı * Birim Genişliği) + (Kaybolan Aradaki Marginler ve Spacingler)
      double displayWidth = (units * currentUnitWidth) + (units - 1) * (cardMargin + wrapSpacing);
      
      // Yükseklik Oranlaması
      double scale = currentUnitWidth / baseUnitWidth;
      double displayHeight = (height?.value ?? (btnHigh.value * 1.5)) * (isTablet.value ? 1.0 : scale);
      double displayIconHeight = (iconHeight?.value ?? (btnIcoHigh.value * 1.5)) * (isTablet.value ? 1.0 : scale);

      final Widget card = AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: displayWidth,
        height: displayHeight,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
          boxShadow: shadows,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isBlocked ? null : onTap,
            onLongPress: isBlocked ? null : onLongPress,
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 8), // Üstten küçük bir boşluk ile dengeleyelim
                Expanded(
                  child: Center(
                    child: isBlocked
                        ? const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                          )
                        : Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: icon,
                              ),
                              if (isAllRooms && hasRoom)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    bottom: isTablet.value ? 10.0 : 6.0, 
                    left: 6, 
                    right: 6,
                    top: 4,
                  ),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isTablet.value ? 15 : 13,
                      fontWeight: FontWeight.bold,
                      color: theme.extension<AppColors>()?.labelText,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // kanal 0 -> Wifi, kanal 10 -> yerel (RS485/Modbus) -- ikisi aynı anda
      // olamaz, aynı köşe rozetini paylaşıyorlar.
      final bool isLocal = channel == 10;
      if (!isWifi && !isLocal) return card;

      // Rozet kartın (butonun) kendisine göre konumlanıyor -- ikonun Stack'i
      // içinde değil, köşeye yakın olsun diye burada, en dışta.
      return Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          Positioned(
            top: 14,
            left: 16,
            child: Icon(
              isWifi ? Icons.wifi : Icons.cable,
              size: 24,
              color: Colors.grey.withOpacity(0.55),
              shadows: [
                Shadow(color: Colors.white.withOpacity(0.6), blurRadius: 2),
              ],
            ),
          ),
        ],
      );
    });
  }
}
