import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../user/userManagementService.dart';
import '../user/appUser.dart';
import '../comminication/dataBridgeServis.dart';
import 'LogicButton.dart';
import 'TermostatButton.dart';
import 'anahtar.dart';
import 'tool.dart';
import 'ins_ui_helper.dart';

// Hareket sensöründe sadece bu iki process anlamlı -- firmware'in
// isSensorDriven (PR_ONOFF/PR_MXMN) mantığı, Occupied/Vacant event'lerine
// SADECE bu ikisinde tepki veriyor; touchKeyProcessOptions'ta bilerek
// dışarıda bırakılmıştı çünkü tuş bunları asla üretmez, burası tam tersi.
const List<command_type> motionProcessOptions = [
  command_type(8, "Max On/Off (Sens)"),
  command_type(10, "MxOn/MnOff(Sens)"),
];

bool _isMotionConfigOpen = false;

void showMotionConfigPopup(int deviceId, int channel, InsIntroScn initialIns) {
  if (_isMotionConfigOpen) return; // hızlı art arda tıklama -- aynı popup iki kez açılmasın
  _isMotionConfigOpen = true;
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

  final RxBool isSaving = false.obs;
  StreamSubscription? saveSubscription;
  Timer? saveTimeoutTimer;

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
                    items = [
                      const DropdownMenuItem(value: 99, child: Text("Tüm Lambalar", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                      ...userManager.activeDevices
                          .where((d) => d is! LButtonDevice && d is! AnahtarDevice && d is! ThermostatDevice)
                          .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name ?? "Cihaz ${d.id}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
                    ];
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
                      value: motionProcessOptions.any((e) => e.id == selectedProcess.value) ? selectedProcess.value : motionProcessOptions.first.id,
                      isExpanded: true,
                      items: motionProcessOptions.map((pt) => DropdownMenuItem(
                        value: pt.id,
                        child: Text(pt.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      )).toList(),
                      onChanged: (v) => selectedProcess.value = v!,
                    ),
                  ),
                )),

                Obx(() {
                  final desc = processDescriptions[selectedProcess.value];
                  if (desc == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
                    child: Text(desc, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.6), fontStyle: FontStyle.italic)),
                  );
                }),

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
          child: Obx(() => Row(
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
                   showFilterWindow(Get.context!, instanceLabel, deviceId, initialIns.iadr, channel, isMotion: true);
                }, iconSize: 40, fontSize: 15),
                buildBottomIconButton(Icons.access_time, "Zaman", Colors.orange, () {
                   showTimersWindow(Get.context!, instanceLabel, deviceId, initialIns.iadr, channel, stuckLabel: "Bekleme Süresi (dk)");
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
              if (isSaving.value)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 40, height: 40, child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 3))),
                      SizedBox(height: 6),
                      Text("Kaydediliyor...", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else
                buildBottomIconButton(Icons.check_circle_outline, "Kaydet", Colors.green, () {
                  // Hedefin bulunduğu DALI kanalı: Lamba/Tüm-Lambalar için hedef
                  // cihazın kendi kanalı (Tüm Lambalar'da cihaz yok, bu yüzden
                  // Grup/Senaryo'daki gibi Anahtar'ın kendi kanalına düşer);
                  // Grup/Senaryo SADECE Anahtar'ın kendi bulunduğu kanalda uygulanır.
                  int insKanal = 255;
                  if (selectedCommand.value == 0 && selectedTargetId.value != 99) {
                    final targetDev = userManager.activeDevices.firstWhereOrNull(
                      (d) => d.id == selectedTargetId.value && d is! LButtonDevice && d is! AnahtarDevice && d is! ThermostatDevice
                    );
                    if (targetDev != null) {
                      insKanal = targetDev.channel;
                    }
                  } else if ((selectedCommand.value == 0 && selectedTargetId.value == 99) ||
                      selectedCommand.value == 1 || selectedCommand.value == 2) {
                    insKanal = channel;
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

                  // Anahtar'ın PIR mode1 bloğu (main.c, KEY_OCCUPIED/KEY_VACANT)
                  // sadece Lamba ve Grup hedeflerini destekliyor -- Senaryo o
                  // blokta hiç ele alınmıyor (scene_on sadece KEY_PRESSED'te
                  // çalışıyor), Anahtar (virtual switch) hiç işlenmiyor. Bu
                  // yüzden mode 1 yazımı sadece Lamba/Tüm-Lambalar/Grup için yapılır.
                  final needsLocalWrite = selectedCommand.value == 0 || selectedCommand.value == 1;

                  if (!needsLocalWrite) {
                    Get.back();
                    Get.snackbar("Başarılı", "Ayarlar güncellendi.");
                    return;
                  }

                  isSaving.value = true;
                  saveSubscription = Get.find<DataBridgeService>().dataStream.listen((data) {
                    final payload = data['full_payload'];
                    if (payload is Map &&
                        payload['com'] == 'set_local_action' &&
                        payload['adr'] == deviceId &&
                        payload['ins'] == initialIns.iadr) {
                      saveTimeoutTimer?.cancel();
                      saveSubscription?.cancel();
                      isSaving.value = false;
                      Get.back();
                      Get.snackbar("Başarılı", "Ayarlar güncellendi.");
                    }
                  });
                  saveTimeoutTimer = Timer(const Duration(seconds: 20), () {
                    saveSubscription?.cancel();
                    isSaving.value = false;
                    Get.back();
                    Get.snackbar("Zaman Aşımı", "Anahtar'dan onay alınamadı, tekrar deneyin.", backgroundColor: Colors.orange);
                  });

                  sendToOutbox({
                    "com": "set_local_action",
                    "adr": deviceId,
                    "ins": initialIns.iadr,
                    "kanal": channel,
                    "group0": selectedCommand.value,
                    "group1": selectedProcess.value,
                    "group2": selectedTargetId.value,
                  });
                }, iconSize: 40, fontSize: 15),
            ],
          )),
        ),
      ],
    ),
  ).then((_) {
    worker.dispose();
    saveSubscription?.cancel();
    saveTimeoutTimer?.cancel();
    _isMotionConfigOpen = false;
  });
}
