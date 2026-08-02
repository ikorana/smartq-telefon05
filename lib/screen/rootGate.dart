import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:telefon05/screen/userSelection/userSelectionUI.dart';
import '../comminication/comminication.dart';
import '../user/userManagementService.dart';
import 'deviceSetup/deviceSetupUI.dart';
import 'dashboard/dashboardUI.dart';
//import 'userSelection/userSelectionUI.dart';

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final comm = Get.find<ComminicationServis>();
    final userManager = Get.find<UserManagementService>();

    return Obx(() {
      final connection = comm.rxConnectionStatus.value;
      final splashFinished = comm.isSplashFinished.value;

      // SADECE splash süresi bittiyse VE internet varsa içeriğe geç
      if (splashFinished && 
          connection.status != ConnectionStatus.connecting && 
          connection.status != ConnectionStatus.none && 
          connection.hasInternet) {
        
        if (userManager.activeUser.value != null) {
          // Kullanıcı seçiliyse Dashboard ekranına yönlendir
          return const DashboardPage();
        } else {
          // Kullanıcı seçili değilse UserSelectionPage ekranını göster
          return const UserSelectionPage();
        }
      }

      // Geri kalan durumlarda (Splash süresi bitmediyse VEYA internet yoksa) Splash ekranını göster
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 150,
                height: 150,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.apps, size: 100, color: Colors.white24),
              ),
              const SizedBox(height: 50),

              if (!splashFinished || connection.status == ConnectionStatus.connecting || connection.status == ConnectionStatus.none) ...[
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'system_starting'.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w300),
                ),
              ] 
              else if (!connection.hasInternet) ...[
                const Icon(Icons.signal_wifi_off, size: 48, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  'no_internet_connection'.tr,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                  child: Text(
                    'internet_required'.tr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => comm.init(DeviceType.phone),
                  icon: const Icon(Icons.refresh),
                  label: Text('try_again'.tr),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                )
              ],
            ],
          ),
        ),
      );
    });
  }
}
