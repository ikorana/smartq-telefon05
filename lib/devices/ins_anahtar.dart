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

// Tuş (touch key) ekranında sadece burada gerçekten çalışabilecek aksiyonlar
// gösterilir -- "Max On/Off (Sens)" ve "MxOn/MnOff(Sens)" (id 8/10) sadece
// hareket sensörü instance'ında anlamlı (Occupied/Vacant event'lerine tepki
// verirler); bir tuş bunları asla üretmez. Hareket sensörü ekranı ayrı ele
// alınacak, bu ikisi o zaman oraya eklenir.
const List<command_type> touchKeyProcessOptions = [
  command_type(0, "Last Level"),
  command_type(1, "Off"),
  command_type(2, "Toggle"),
  command_type(3, "Up Dim"),
  command_type(4, "Down Dim"),
  command_type(5, "Arc Power"),
  command_type(6, "Max Level"),
  command_type(7, "Min Level"),
  command_type(9, "Toggle (Max)"),
  command_type(11, "Toggle Dim"),
  command_type(15, "Seçiniz"),
];

// Hedef "Anahtar" (virtual switch, CM_SWITCH) iken firmware sadece üç
// davranışı ayırt ediyor (bkz. controller trigger_instance): Off (id=1),
// Toggle (id=2), ve bunların dışındaki HER şey "Açık" olarak davranıyor --
// bu yüzden burada da sadece bu üç anlamlı seçenek gösteriliyor.
const List<command_type> switchTargetProcessOptions = [
  command_type(0, "Açık"),
  command_type(1, "Kapalı"),
  command_type(2, "Toggle"),
];

bool _isSwitchConfigOpen = false;

void showSwitchConfigPopup(int deviceId, int channel, InsIntroScn initialIns) {
  if (_isSwitchConfigOpen) return; // hızlı art arda tıklama -- aynı popup iki kez açılmasın
  _isSwitchConfigOpen = true;
  final theme = Get.theme;
  final userManager = Get.find<UserManagementService>();
  const String instanceLabel = "Anahtar";
  
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
  });

  sendToOutbox({
    "com": "qinstance",
    "adr": deviceId,
    "ins": initialIns.iadr,
    "kanal": channel
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
              // Yerel (kanal=10) anahtarlarda Aktif/Pasif durumu device.json'daki donanım
              // atamasından (is_assigned) geliyor — app üzerinden elle değiştirilemez.
              if (channel != 10) ...[
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
              ],

              // Hedef tipi seçimi: Lamba herhangi bir kanaldaki cihaz olabilir
              // (kendi kanalı kaydedilir). Grup ve Senaryo ise DALI'de bus'a
              // (kanala) özgü kavramlardır -- "cihaz" değildirler, bu yüzden
              // ayrı bir kanal bilgisi taşımazlar. O yüzden Grup/Senaryo
              // seçimi SADECE bu Anahtar'ın kendi bulunduğu DALI kanalında
              // uygulanır; farklı kanaldaki bir grup/senaryo hedeflenemez.
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
                      // id=99: gerçek bir cihaz değil, DALI broadcast (0xFF) hedefi
                      // için sentinel -- gönderilirken 255 kullanılmıyor çünkü 255
                      // firmware/controller'da zaten "hedef atanmamış" anlamına geliyor.
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

              // Aksiyon (process) ve ON/OFF alanları yerel (kanal=10) anahtarlarda kullanılmıyor:
              // davranış tamamen instance tipine (Anahtar/Switch) göre sabit, process'ten
              // bağımsız çalışıyor (bkz. firmware trigger_instance). DALI'de ise ikisi de geçerli.
              if (channel != 10) ...[
                // Senaryo hedefinde Aksiyon'un hiçbir karşılığı yok -- firmware
                // (hem controller hem Anahtar mode1) her zaman sadece "sahneyi
                // çağır" yapıyor, isl/process tamamen yok sayılıyor (senaryonun
                // DALI'de bir "kapalı" karşılığı da yok). Kafa karıştırmasın
                // diye dropdown yerine sabit bir açıklama gösteriliyor.
                Obx(() {
                  if (selectedCommand.value == 2) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        "Tuşa basıldığında seçilen sahne çağrılır.",
                        style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withOpacity(0.7), fontStyle: FontStyle.italic),
                      ),
                    );
                  }
                  final options = selectedCommand.value == 3 ? switchTargetProcessOptions : touchKeyProcessOptions;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: options.any((e) => e.id == selectedProcess.value) ? selectedProcess.value : options.first.id,
                        isExpanded: true,
                        items: options.map((pt) => DropdownMenuItem(
                          value: pt.id,
                          child: Text(pt.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        )).toList(),
                        onChanged: (v) => selectedProcess.value = v!,
                      ),
                    ),
                  );
                }),

                Obx(() {
                  if (selectedCommand.value == 2 || selectedCommand.value == 3) return const SizedBox.shrink();
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
              // Filtre/Zaman: DALI'ye özgü kavramlar (event filtresi, sahne zamanlayıcı),
              // yerel (kanal=10) anahtarlarda karşılığı yok.
              if (channel != 10) ...[
                buildBottomIconButton(Icons.filter_alt_outlined, "Filtre", theme.colorScheme.primary, () {
                   showFilterWindow(Get.context!, instanceLabel, deviceId, initialIns.iadr, channel);
                }, iconSize: 40, fontSize: 15),
                buildBottomIconButton(Icons.access_time, "Zaman", Colors.orange, () {
                   showTimersWindow(Get.context!, instanceLabel, deviceId, initialIns.iadr, channel);
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
                  // Hedefin bulunduğu DALI kanalı: Lamba için hedef cihazın
                  // kendi kanalı; Grup/Senaryo/Tüm Lambalar için ise hedef bir
                  // "cihaz" değil (soyut grup/senaryo no ya da broadcast), bu
                  // üçü DALI'da bus'a özgüdür -- yani seçim SADECE Anahtar'ın
                  // kendi bulunduğu kanalda uygulanır, farklı kanaldaki bir
                  // grup/senaryo/broadcast hedeflenemez. Bu yüzden fallback
                  // olarak Anahtar'ın kendi kanalı (channel) kullanılır.
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
                  });

                  // Aynı hedef+aksiyon Anahtar'ın kendisine de yazılır ki
                  // cihaz mode 1'deyken (kontrolörsüz, lokal kontrol) de aynı
                  // davranışı sergileyebilsin. Hedef tipi "Anahtar" (3) ya da
                  // aksiyon Anahtar'da desteklenmeyen bir değerse (8/10,
                  // sadece hareket sensörü için) atlanır -- bunların Anahtar
                  // tarafında karşılığı yok.
                  final needsLocalWrite = selectedCommand.value != 3 &&
                      selectedCommand.value != 4 &&
                      touchKeyProcessOptions.any((e) => e.id == selectedProcess.value) &&
                      selectedProcess.value != 15;

                  if (!needsLocalWrite) {
                    Get.back();
                    Get.snackbar("Başarılı", "Ayarlar güncellendi.");
                    return;
                  }

                  // Anahtar'a yazma birkaç DALI gidiş-dönüşü gerektirdiği
                  // (group0/1/2 + filtre, her biri ayrı bir DTR0-set +
                  // doğrulama döngüsü) için birkaç saniye sürebilir --
                  // kullanıcı "bitti mi bitmedi mi" bilemesin diye gerçek
                  // "set_local_action" yanıtı gelene (ya da zaman aşımına
                  // uğrayana) kadar ekranı kapatmıyoruz.
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
    _isSwitchConfigOpen = false;
  });
}
