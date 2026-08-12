import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../user/userManagementService.dart';
import '../user/appUser.dart';
import 'base.dart';
import 'ins_ui_helper.dart';

// Termostatın hedefi (hangi röle/kontaktör) artık SADECE oluşturma anında
// ("Anahtar Ekle" ekranı, deviceSetupController.addSwitch) atanıyor — burada
// tekrar atama/kaydetme yok, bilerek tek nokta bırakıldı. Bu popup salt bilgi
// amaçlı: mevcut durumu gösterir, "Yenile" ile taze veri ister.
void showTempPopup(int deviceId, int channel, InsIntroScn initialIns, {String? label}) {
  final theme = Get.theme;
  final userManager = Get.find<UserManagementService>();
  final String instanceLabel = label ?? "Isı";

  InsIntroScn getUpdatedIns() {
    return userManager.activeInsIntroList.firstWhere(
      (i) => i.adr == initialIns.adr && i.iadr == initialIns.iadr,
      orElse: () => initialIns,
    );
  }

  final RxInt status = (getUpdatedIns().act == 1 ? 1 : 0).obs;

  final worker = ever(userManager.activeInsIntroList, (_) {
    status.value = (getUpdatedIns().act == 1 ? 1 : 0);
  });

  sendToOutbox({
    "com": "qinstance",
    "adr": deviceId,
    "ins": initialIns.iadr,
    "kanal": channel
  });

  Get.dialog(
    AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        "$instanceLabel ${initialIns.iadr} Durumu",
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      content: SizedBox(
        width: 500,
        child: Obx(() => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                status.value == 1 ? Icons.check_circle : Icons.cancel,
                color: status.value == 1 ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 10),
              Text(
                status.value == 1 ? "Aktif" : "Pasif",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        )),
      ),
      actionsPadding: const EdgeInsets.symmetric(vertical: 12),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            buildBottomIconButton(Icons.refresh, "Yenile", Colors.blueGrey, () {
              sendToOutbox({
                "com": "qinstance",
                "adr": deviceId,
                "ins": initialIns.iadr,
                "kanal": channel
              });
            }, iconSize: 40, fontSize: 15),
            buildBottomIconButton(Icons.cancel_outlined, "Kapat", Colors.red, () {
              Get.back();
            }, iconSize: 40, fontSize: 15),
          ],
        ),
      ],
    ),
  ).then((_) => worker.dispose());
}

void showLuxPopup(InsIntroScn ins) {
  Get.defaultDialog(
    title: "Işık ${ins.iadr}",
    titleStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
    contentPadding: const EdgeInsets.all(20),
    middleText: "Parlaklık (Lux) değeri sorgulanıyor...",
    middleTextStyle: const TextStyle(fontSize: 16),
    textConfirm: "KAPAT",
    confirmTextColor: Colors.white,
    onConfirm: () => Get.back(),
  );
}
