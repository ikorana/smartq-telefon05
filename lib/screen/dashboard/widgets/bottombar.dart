import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../dashboardController.dart';
import '../../deviceSetup/deviceSetupUI.dart';
import '../../deviceSetup/deviceSetupController.dart';
import 'powerActionDialog.dart';

class DashboardBottombar extends StatelessWidget {
  const DashboardBottombar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = Get.find<DashboardController>();

    return Container(
      height: 70 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Obx(() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(
            context, 
            Icons.home_outlined, 
            'home'.tr, 
            controller.selectedIndex.value == 0, 
            () => controller.changeIndex(0)
          ),
          
          // REFRESH BUTONU
          _buildRefreshNavItem(context),

          // POWER BUTONU (Eski Senaryolar Butonu)
          _buildNavItem(
            context,
            Icons.power_settings_new,
            'power'.tr,
            false,
            () => Get.dialog(const PowerActionDialog())
          ),

          _buildNavItem(
            context, 
            Icons.settings_outlined, 
            'setup'.tr, 
            controller.selectedIndex.value == 3, 
            () {
              controller.changeIndex(3);
              if (!Get.isRegistered<DeviceSetupController>()) {
                Get.put(DeviceSetupController());
              }
              Get.to(() => DeviceSetupPage());
            }
          ),

          // ÇIKIŞ BUTONU
          _buildNavItem(
            context, 
            Icons.logout, 
            'exit_app'.tr, 
            false, 
            () {
              Get.defaultDialog(
                title: 'attention'.tr,
                middleText: "exit_confirm_msg".tr,
                textConfirm: 'yes'.tr,
                textCancel: 'no'.tr,
                confirmTextColor: Colors.white,
                buttonColor: theme.colorScheme.primary,
                onConfirm: () {
                  if (Platform.isAndroid) {
                    SystemNavigator.pop();
                  } else {
                    exit(0);
                  }
                },
              );
            }
          ),
        ],
      )),
    );
  }

  Widget _buildRefreshNavItem(BuildContext context) {
    final controller = Get.find<DashboardController>();
    final theme = Theme.of(context);
    
    return Obx(() {
      final isRefreshing = controller.isRefreshing.value;
      final count = controller.refreshCount.value;

      return InkWell(
        onTap: isRefreshing ? null : () => controller.sendRefreshCommand(),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: 70,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // Dönen ikon animasyonu (Busy Animation)
                  if (isRefreshing)
                    const _RotatingRefreshIcon()
                  else
                    Icon(
                      Icons.refresh, 
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4), 
                      size: 24
                    ),

                  // Badge (Count)
                  if (isRefreshing)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 2,
                            )
                          ],
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'refresh'.tr,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isRefreshing 
                      ? theme.colorScheme.primary 
                      : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, bool isSelected, VoidCallback onTap) {
    final theme = Theme.of(context);
    final color = isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.4);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yenileme sırasında dönen ikon için yardımcı widget
class _RotatingRefreshIcon extends StatefulWidget {
  const _RotatingRefreshIcon();

  @override
  State<_RotatingRefreshIcon> createState() => _RotatingRefreshIconState();
}

class _RotatingRefreshIconState extends State<_RotatingRefreshIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(
        Icons.refresh,
        color: Theme.of(context).colorScheme.primary,
        size: 24,
      ),
    );
  }
}
