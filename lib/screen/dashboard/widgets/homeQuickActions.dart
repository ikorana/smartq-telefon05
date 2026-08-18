import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:telefon05/main.dart';
import '../dashboardController.dart';
import '../keypad.dart';
import '../../../user/userManagementService.dart';
import '../../../devices/energy.dart';
import '../../../devices/asansor.dart';
import '../../../devices/gas.dart';
import '../../../devices/water.dart';
import '../../../devices/mwater.dart';
import '../../../devices/door.dart';
import '../../../devices/garage.dart';
import 'irrigation_dialog.dart';

class HomeQuickActions extends StatefulWidget {
  const HomeQuickActions({super.key});

  @override
  State<HomeQuickActions> createState() => _HomeQuickActionsState();
}

class _HomeQuickActionsState extends State<HomeQuickActions> {
  final controller = Get.find<DashboardController>();

  @override
  void initState() {
    super.initState();
    // Widget aktive edildiğinde (ekrana her geldiğinde) güncel mod bilgisini iste
    controller.getSystemMode();
    controller.getIrrigationStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final int currentMode = controller.activeMode.value;
      final int alarmState = controller.alarmState.value;

      // Alarm Durumuna Göre UI Ayarları
      String alarmLabel;
      IconData alarmIcon;
      Color alarmColor;
      bool isSelected;

      switch (alarmState) {
        case 2: // ON
          alarmLabel = 'alarm_on'.tr;
          alarmIcon = Icons.security;
          alarmColor = Colors.green;
          isSelected = true;
          break;
        case 1: // PENDING
          alarmLabel = 'alarm_pending'.tr; // 'alarm_pending' çevirisi eklenmeli
          alarmIcon = Icons.security_update_warning;
          alarmColor = Colors.orange;
          isSelected = true;
          break;
        case 0: // OFF
        default:
          alarmLabel = 'alarm_off'.tr;
          alarmIcon = Icons.gpp_maybe;
          alarmColor = Colors.redAccent;
          isSelected = false;
          break;
      }

      // Buton Genişlik Hesaplaması (2'li dizilim için)
      // (Ekran Genişliği - 20px dış padding - 5px ara boşluk) / 2
      double buttonWidth = (scrWidth.value - 20 - 5) / 2;

      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. GURUP: HIZLI AKSİYONLAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                alignment: WrapAlignment.start,
                runAlignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: buttonWidth,
                    height: 75,
                    child: _buildActionButton(
                      context,
                      label: alarmLabel,
                      icon: alarmIcon,
                      color: alarmColor,
                      isSelected: isSelected,
                      onTap: () async {
                        if (alarmState == 2) {
                          bool ok = await KeypadWidget.show(
                            message: "Alarmı Kapatmak İçin Şifre Girin",
                            password: "1210",
                          );
                          if (ok) controller.toggleAlarm();
                        } else {
                          controller.toggleAlarm();
                        }
                      },
                    ),
                  ),
                  if (isTablet.value) ...[
                    SizedBox(
                      width: buttonWidth,
                      height: 75,
                      child: _buildActionButton(
                        context,
                        label: controller.isIrrigationRunning.value 
                            ? 'garden_watering_active'.tr 
                            : 'garden_watering'.tr,
                        icon: Icons.water_drop,
                        color: Colors.cyan,
                        isSelected: controller.isIrrigationRunning.value,
                        onTap: () => Get.dialog(const IrrigationDialog()),
                      ),
                    ),
                    SizedBox(
                      width: buttonWidth,
                      height: 75,
                      child: _buildActionButton(
                        context,
                        label: 'env_lighting'.tr,
                        icon: Icons.light_mode_outlined,
                        color: Colors.amber,
                        isSelected: false,
                        onTap: () {},
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 15),

            // 2. GURUP: SİSTEM MODLARI
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                alignment: WrapAlignment.start,
                runAlignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: buttonWidth,
                    height: 75,
                    child: _buildActionButton(
                      context,
                      label: 'normal_mode'.tr,
                      icon: Icons.home,
                      color: Colors.blueGrey,
                      isSelected: currentMode == 0,
                      onTap: () => controller.setSystemMode(0),
                    ),
                  ),
                  SizedBox(
                    width: buttonWidth,
                    height: 75,
                    child: _buildActionButton(
                      context,
                      label: 'exit_home'.tr,
                      icon: Icons.exit_to_app,
                      color: Colors.blueAccent,
                      isSelected: currentMode == 1,
                      onTap: () async {
                        final bool? result = await Get.dialog<bool>(
                          AlertDialog(
                            title: const Text("Alarm"),
                            content: const Text("Alarmı Açmamı İstermisiniz?"),
                            actions: [
                              TextButton(onPressed: () => Get.back(result: false), child: Text('no'.tr)),
                              TextButton(onPressed: () => Get.back(result: true), child: Text('yes'.tr)),
                            ],
                          ),
                        );
                        if (result != null) {
                          controller.setSystemMode(1, alarm: result ? 1 : 0);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // 3. GURUP: ÖZEL CİHAZLAR (ENERJİ, ASANSÖR VE GAZ VE SU)
            Obx(() {
              final userManager = Get.find<UserManagementService>();
              final energyDevices = userManager.activeDevices.whereType<EnergyDevice>().toList();
              final asansorDevices = isTablet.value ? userManager.activeDevices.whereType<AsansorDevice>().toList() : <AsansorDevice>[];
              final gasDevices = userManager.activeDevices.whereType<GasDevice>().toList();
              final waterDevices = userManager.activeDevices.whereType<WaterDevice>().toList();
              final mWaterDevices = userManager.activeDevices.whereType<MWaterDevice>().toList();
              final doorDevices = userManager.activeDevices.whereType<DoorDevice>().toList();
              final garageDevices = userManager.activeDevices.whereType<GarageDevice>().toList();
              
              if (energyDevices.isEmpty && asansorDevices.isEmpty && gasDevices.isEmpty && waterDevices.isEmpty && mWaterDevices.isEmpty && doorDevices.isEmpty && garageDevices.isEmpty) return const SizedBox.shrink();
              
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  alignment: WrapAlignment.start,
                  children: [
                    ...energyDevices.map((d) => d.buildWidget()),
                    ...asansorDevices.map((d) => d.buildWidget()),
                    ...gasDevices.map((d) => d.buildWidget()),
                    ...waterDevices.map((d) => d.buildWidget()),
                    ...mWaterDevices.map((d) => d.buildWidget()),
                    ...doorDevices.map((d) => d.buildWidget()),
                    ...garageDevices.map((d) => d.buildWidget()),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    });
  }

  Widget _buildActionButton(BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.2), 
            width: isSelected ? 2.0 : 1.2
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.2) : color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon, 
                color: color, 
                size: 20
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isSelected ? color : theme.colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
