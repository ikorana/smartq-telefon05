import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../user/userManagementService.dart';
import '../user/appUser.dart';
import 'LogicButton.dart';
import 'TermostatButton.dart';
import 'anahtar.dart';
import 'tool.dart';
import 'ins_ui_helper.dart';

void showMotionConfigPopup(int deviceId, int channel, InsIntroScn initialIns) {
  final theme = Get.theme;
  final userManager = Get.find<UserManagementService>();
  const String instanceLabel = "Hareket";
  
  InsIntroScn getUpdatedIns() {
    return userManager.activeInsIntroList.firstWhere(
      (i) => i.adr == initialIns.adr && i.iadr == initialIns.iadr,
      orElse: () => initialIns,
    );
  }

  final RxInt status = (getUpdatedIns().act == 1 ? 1 : 0).obs;
  final RxInt action = (getUpdatedIns().stat == 255 ? 1 : 0).obs;
  final RxInt selectedCommand = getUpdatedIns().cm.obs;
  final RxInt selectedProcess = getUpdatedIns().proc.obs;
  final RxInt selectedTargetId = getUpdatedIns().cmadr.obs;
  // Yerel (kanal=10) hareket sensörlerinde "retrigger" timer süresi (DAKİKA) — tset alanı
  // üzerinden taşınıyor (termostatlarda kullanılan "hedef sıcaklık" alanının bu tipte karşılığı yok).
  final RxInt sureDakika = (getUpdatedIns().tset > 0 ? getUpdatedIns().tset : 1).obs;

  final worker = ever(userManager.activeInsIntroList, (_) {
    final updated = getUpdatedIns();
    status.value = (updated.act == 1 ? 1 : 0);
    action.value = (updated.stat == 255 ? 1 : 0);
    selectedCommand.value = updated.cm;
    selectedProcess.value = updated.proc;
    selectedTargetId.value = updated.cmadr;
    if (updated.tset > 0) sureDakika.value = updated.tset;
  });

  Get.dialog(
    AlertDialog(
      title: Text(
        "$instanceLabel ${initialIns.iadr} Ayarları", 
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), // Büyütüldü
        textAlign: TextAlign.center,
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: SizedBox(
        width: 500, // Genişlik artırıldı
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              
              Obx(() => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: getcommandtype.any((e) => e.id == selectedCommand.value) ? selectedCommand.value : 4,
                    isExpanded: true,
                    items: getcommandtype.map((ct) => DropdownMenuItem(
                      value: ct.id,
                      child: Text(ct.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    )).toList(),
                    onChanged: (v) {
                      selectedCommand.value = v!;
                      selectedTargetId.value = 255;
                    },
                  ),
                ),
              )),
              const SizedBox(height: 20),

              Obx(() {
                List<DropdownMenuItem<int>> items = [];

                switch (selectedCommand.value) {
                  case 0: 
                    items = userManager.activeDevices
                        .where((d) => d is! LButtonDevice && d is! AnahtarDevice && d is! ThermostatDevice)
                        .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name ?? "Cihaz ${d.id}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))))
                        .toList();
                    break;
                  case 1: 
                    items = userManager.activeGroups
                        .map((g) => DropdownMenuItem(value: g.id, child: Text(g.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))))
                        .toList();
                    break;
                  case 2: 
                    items = userManager.activeScenes
                        .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))))
                        .toList();
                    break;
                  case 3: 
                    items = userManager.activeSwitches
                        .where((s) => s.type == 0)
                        .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))))
                        .toList();
                    break;
                  default:
                    return const SizedBox.shrink();
                }

                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Text("Seçilebilir öğe bulunamadı.", style: TextStyle(color: Colors.red.shade300, fontSize: 14, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: items.any((i) => i.value == selectedTargetId.value) ? selectedTargetId.value : items.first.value,
                          isExpanded: true,
                          items: items,
                          onChanged: (v) => selectedTargetId.value = v!,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              }),

              // Aksiyon (process) ve ON/OFF: DALI'de geçerli. Yerelde (kanal=10) davranış
              // sabit (aç + retrigger timer) — onun yerine timer süresi ayarlanıyor.
              if (channel != 10) ...[
                Obx(() => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: getprocesstype.any((e) => e.id == selectedProcess.value) ? selectedProcess.value : 15,
                      isExpanded: true,
                      items: getprocesstype.map((pt) => DropdownMenuItem(
                        value: pt.id,
                        child: Text(pt.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      )).toList(),
                      onChanged: (v) => selectedProcess.value = v!,
                    ),
                  ),
                )),

                const SizedBox(height: 25),

                Obx(() => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    buildCompactRadio(1, action.value, "ON", (v) => action.value = v!),
                    buildCompactRadio(0, action.value, "OFF", (v) => action.value = v!),
                  ],
                )),
                const SizedBox(height: 15),
              ] else ...[
                Obx(() => Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Süre (dk)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              if (sureDakika.value > 1) sureDakika.value -= 1;
                            },
                          ),
                          SizedBox(
                            width: 36,
                            child: Text(
                              "${sureDakika.value}",
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => sureDakika.value += 1,
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 15),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(vertical: 12),
      actions: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
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
              // Filtre/Zaman/C.Hold: DALI'ye özgü kavramlar, yerel (kanal=10) anahtarlarda karşılığı yok.
              if (channel != 10) ...[
                buildBottomIconButton(Icons.filter_alt_outlined, "Filtre", theme.colorScheme.primary, () {
                   showFilterWindow(Get.context!, instanceLabel, deviceId, initialIns.iadr, channel);
                }, iconSize: 40, fontSize: 15),
                buildBottomIconButton(Icons.access_time, "Zaman", Colors.orange, () {
                   showTimersWindow(Get.context!, instanceLabel, deviceId, initialIns.iadr, channel);
                }, iconSize: 40, fontSize: 15),
                buildBottomIconButton(Icons.back_hand_outlined, "C.Hold", Colors.deepPurple, () {
                  sendToOutbox({
                    "com": "cancel_hold",
                    "adr": deviceId,
                    "ins": initialIns.iadr,
                    "kanal": channel
                  });
                }, iconSize: 40, fontSize: 15),
              ],
              buildBottomIconButton(Icons.cancel_outlined, "İptal", Colors.red, () {
                Get.back();
              }, iconSize: 40, fontSize: 15),
              buildBottomIconButton(Icons.check_circle_outline, "Kaydet", Colors.green, () {
                int insKanal = 255;
                if (selectedCommand.value == 0) {
                  final targetDev = userManager.activeDevices.firstWhereOrNull(
                    (d) => d.id == selectedTargetId.value && d is! LButtonDevice && d is! AnahtarDevice && d is! ThermostatDevice
                  );
                  if (targetDev != null) {
                    insKanal = targetDev.channel;
                  }
                }

                sendToOutbox({
                  "com": "set_instance",
                  "adr": deviceId,
                  "ins": initialIns.iadr,
                  "kanal": channel,
                  "act": status.value,
                  "stat": action.value == 1 ? 255 : 0,
                  "cmtype": selectedCommand.value,
                  "cmadr": selectedTargetId.value,
                  "pro": selectedProcess.value,
                  "ins_kanal": insKanal,
                  "tset": sureDakika.value,
                });
                Get.back();
                Get.snackbar("Başarılı", "Ayarlar güncellendi.");
              }, iconSize: 40, fontSize: 15),
            ],
          ),
        ),
      ],
    ),
  ).then((_) => worker.dispose());
}
