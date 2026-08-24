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
bool _isTempPopupOpen = false;

void showTempPopup(int deviceId, int channel, InsIntroScn initialIns, {String? label}) {
  if (_isTempPopupOpen) return; // hızlı art arda tıklama -- aynı popup iki kez açılmasın
  _isTempPopupOpen = true;
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
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              buildCompactRadio(1, status.value, "Aktif", (v) => status.value = v!),
              buildCompactRadio(0, status.value, "Pasif", (v) => status.value = v!),
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
            buildBottomIconButton(Icons.access_time, "Zaman", Colors.orange, () {
              showTimersWindow(Get.context!, instanceLabel, deviceId, initialIns.iadr, channel, stuckOnly: true, stuckLabel: "Okuma Aralığı (sn)");
            }, iconSize: 40, fontSize: 15),
            buildBottomIconButton(Icons.check_circle_outline, "Kaydet", Colors.green, () {
              sendToOutbox({
                "com": "set_instance",
                "adr": deviceId,
                "ins": initialIns.iadr,
                "kanal": channel,
                "act": status.value,
              });
              Get.back();
              Get.snackbar("Başarılı", "Ayarlar güncellendi.");
            }, iconSize: 40, fontSize: 15),
            buildBottomIconButton(Icons.cancel_outlined, "Kapat", Colors.red, () {
              Get.back();
            }, iconSize: 40, fontSize: 15),
          ],
        ),
      ],
    ),
  ).then((_) {
    worker.dispose();
    _isTempPopupOpen = false;
  });
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
