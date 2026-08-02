import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../user/userManagementService.dart';
import '../dashboardController.dart';
import 'groupBUTTON.dart';
import 'senaryoBUTTON.dart';
import 'homeQuickActions.dart';
import '../../../devices/base.dart';
import '../../../devices/anahtar.dart';
import '../../../devices/gas.dart';
import '../../../devices/energy.dart';
import '../../../devices/asansor.dart';
import '../../../devices/water.dart';
import '../../../devices/mwater.dart';
import '../../../devices/door.dart';
import '../../../devices/garage.dart';
import '../../../devices/radio.dart';
import '../../../main.dart';

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    final userManager = Get.find<UserManagementService>();
    final controller = Get.find<DashboardController>();
    final theme = Theme.of(context);

    return Obx(() {
      // Navigasyon indexine göre içeriği değiştir
      switch (controller.selectedIndex.value) {
        case 0: // ANA SAYFA (HIZLI AKSİYONLAR)
          return const HomeQuickActions();
        case 1: // GRUPLar SAYFASI
          return _buildGroupsGrid(userManager, theme);
        case 2: // SENARYOLAR SAYFASI
          return _buildScenariosGrid(userManager, theme);
        case 4: // ODALAR VE CİHAZLAR LİSTESİ
          return _buildRoomsAndDevices(userManager, theme, controller);
        default:
          return _buildRoomsAndDevices(userManager, theme, controller);
      }
    });
  }

  Widget _buildGroupsGrid(UserManagementService userManager, ThemeData theme) {
    final visibleGroups = userManager.activeGroups.where((g) => g.icon != 11).toList();

    if (visibleGroups.isEmpty) {
      return _buildEmptyState(
        theme, 
        Icons.groups_outlined, 
        'no_device_found'.tr
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Wrap(
          spacing: 5,
          runSpacing: 5,
          alignment: WrapAlignment.start,
          runAlignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: visibleGroups.map((group) => GroupButton(group: group)).toList(),
        ),
      ),
    );
  }

  Widget _buildScenariosGrid(UserManagementService userManager, ThemeData theme) {
    final visibleScenes = userManager.activeScenes.where((s) => s.icon != 11).toList();

    if (visibleScenes.isEmpty) {
      return _buildEmptyState(
        theme, 
        Icons.auto_awesome_outlined, 
        'no_device_found'.tr
      );
    }

    // Senaryolar da Wrap ile yerleştiriliyor
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Wrap(
          spacing: 5,
          runSpacing: 5,
          alignment: WrapAlignment.start,
          runAlignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: visibleScenes.map((scene) => SenaryoButton(scene: scene)).toList(),
        ),
      ),
    );
  }

  Widget _buildRoomsAndDevices(UserManagementService userManager, ThemeData theme, DashboardController controller) {
    // Toplam sayfa sayısı: 1 (Tüm Odalar) + Oda Sayısı
    final int pageCount = 1 + userManager.activeRooms.length;

    return PageView.builder(
      controller: controller.pageController,
      onPageChanged: controller.onPageChanged,
      itemCount: pageCount,
      itemBuilder: (context, index) {
        int? currentRoomId;
        String emptyTitle = 'no_device_found'.tr;

        if (index == 0) {
          currentRoomId = null; // Tüm Odalar
        } else {
          currentRoomId = userManager.activeRooms[index - 1].id;
        }

        // 1. Tüm Cihazları Birleştir (Fiziksel + Lojik)
        List<BaseDevice> allItems = [];
        
        // Fiziksel cihazları ekle (Gizli olmayanlar)
        allItems.addAll(userManager.activeDevices.where((d) => d.ico != 11));
        
        // Lojik cihazları ekle (Gizli olmayanlar)
        allItems.addAll(userManager.activeLogicDevices.where((d) => d.ico != 11));

        // 2. Oda Filtrelemesi Uygula
        if (currentRoomId != null) {
          allItems = allItems.where((d) => d.roomId == currentRoomId).toList();
        }

        // 3. Cihaz Filtreleme: 
        // - Telefon modunda AnahtarDevice gizlenir
        // - Enerji, Gaz ve Asansör cihazları Ana Sayfada (HomeQuickActions) gösterildiği için buradan gizlenir
        allItems = allItems.where((d) {
          if (!isTablet.value && d is AnahtarDevice) return false;
          if (d is EnergyDevice || d is GasDevice || d is AsansorDevice || d is WaterDevice || d is MWaterDevice || d is DoorDevice || d is GarageDevice || d is RadioDevice) return false;
          return true;
        }).toList();

        if (allItems.isEmpty) {
          return _buildEmptyState(theme, Icons.devices_other_outlined, emptyTitle);
        }

        // Cihazlar (Lambalar vb.) Wrap ile yerleştiriliyor
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Wrap(
              spacing: 5.0,
              runSpacing: 5.0,
              alignment: WrapAlignment.start,
              runAlignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: allItems.map((device) => device.buildWidget()).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme, IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
