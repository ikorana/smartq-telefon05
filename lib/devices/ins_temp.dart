import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../user/userManagementService.dart';
import '../user/appUser.dart';
import 'base.dart';
import 'ins_ui_helper.dart';

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
  
  // Relay device listesi için reaktif değişken
  final RxInt selectedRelayId = getUpdatedIns().cmadr.obs;

  final worker = ever(userManager.activeInsIntroList, (_) {
    final updated = getUpdatedIns();
    status.value = (updated.act == 1 ? 1 : 0);
    selectedRelayId.value = updated.cmadr;
  });

  // Filtreleme: type 7 ve exttype 7 olanlar VEYA adresi 10 olanlar
  final relayDevices = userManager.activeDevices
      .where((d) => d.id == 10 || (d.type == 7 && d.extension == 7))
      .toList();

  Get.dialog(
    AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        "$instanceLabel ${initialIns.iadr} Ayarları",
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), // Büyütüldü
        textAlign: TextAlign.center,
      ),
      content: SizedBox(
        width: 500, // Genişlik artırıldı
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16), // Padding artırıldı
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
                ),
                child: Obx(() => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    buildCompactRadio(1, status.value, "Aktif", (v) => status.value = v!),
                    buildCompactRadio(0, status.value, "Pasif", (v) => status.value = v!),
                  ],
                )),
              ),
              const SizedBox(height: 25),
              
              // Röle Seçim ComboBox (Dropdown)
              Obx(() => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: relayDevices.any((d) => d.id == selectedRelayId.value) 
                        ? selectedRelayId.value 
                        : (relayDevices.isNotEmpty ? relayDevices.first.id : 255),
                    isExpanded: true,
                    hint: const Text("Röle Seçin", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    items: [
                      ...relayDevices.map((d) => DropdownMenuItem(
                        value: d.id,
                        child: Text("${d.name ?? 'Cihaz'} (${d.id})", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      )),
                      if (!relayDevices.any((d) => d.id == 255))
                        const DropdownMenuItem(value: 255, child: Text("Atanmamış", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))
                    ],
                    onChanged: (v) {
                      if (v != null) selectedRelayId.value = v;
                    },
                  ),
                ),
              )),
              const SizedBox(height: 15),
            ],
          ),
        ),
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
            buildBottomIconButton(Icons.cancel_outlined, "İptal", Colors.red, () {
              Get.back();
            }, iconSize: 40, fontSize: 15),
            buildBottomIconButton(Icons.check_circle_outline, "Kaydet", Colors.green, () {
              // ... (kaydet mantığı aynı)
              int relKanal = 255;
              final selectedRelay = relayDevices.firstWhereOrNull((d) => d.id == selectedRelayId.value);
              if (selectedRelay != null) relKanal = selectedRelay.channel;
              sendToOutbox({"com": "set_instance", "adr": deviceId, "ins": initialIns.iadr, "kanal": channel, "act": status.value, "stat": getUpdatedIns().stat, "cmtype": 0, "cmadr": selectedRelayId.value, "pro": getUpdatedIns().proc, "ins_kanal": relKanal});
              Get.back();
              Get.snackbar("Başarılı", "Ayarlar güncellendi.");
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
