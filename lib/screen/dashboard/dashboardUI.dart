import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dashboardController.dart';
import 'widgets/topbar.dart';
import 'widgets/content.dart';
import 'widgets/bottombar.dart';

class DashboardPage extends GetView<DashboardController> {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<DashboardController>()) {
      Get.put(DashboardController());
    }

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Ana İçerik
          const Column(
            children: [
              DashboardTopbar(),
              Expanded(child: DashboardContent()),
              DashboardBottombar(),
            ],
          ),

          // Taşınabilir FAB
          Obx(() {
            final user = controller.activeUser.value;
            if ((user?.ai ?? 1) != 1) return const SizedBox.shrink();

            final bool isListening = controller.isListening.value;
            final bool isPreparing = controller.isVoicePreparing.value;

            return Positioned(
              left: controller.fabPosition.value.dx,
              top: controller.fabPosition.value.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  // Yeni pozisyonu hesapla ve sınırları kontrol et
                  double newX = controller.fabPosition.value.dx + details.delta.dx;
                  double newY = controller.fabPosition.value.dy + details.delta.dy;

                  // Ekran sınırları dışına çıkmasını engelle
                  newX = newX.clamp(0.0, Get.width - 70);
                  newY = newY.clamp(0.0, Get.height - 70);

                  controller.fabPosition.value = Offset(newX, newY);
                },
                child: SizedBox(
                  width: 70,
                  height: 70,
                  child: FloatingActionButton(
                    onPressed: () => controller.toggleVoiceCommand(),
                    backgroundColor: isListening
                        ? Colors.redAccent
                        : isPreparing
                            ? Colors.amber
                            : theme.colorScheme.primary,
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: isPreparing
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Icon(
                            isListening ? Icons.stop : Icons.mic,
                            color: Colors.white,
                            size: 35,
                          ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
