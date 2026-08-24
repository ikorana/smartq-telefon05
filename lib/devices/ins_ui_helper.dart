import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../user/userManagementService.dart';
import '../comminication/comminication.dart' hide DeviceType;
import '../comminication/dataBridgeServis.dart';

typedef HelpCallback = Function(String?);

void sendToOutbox(Map<String, dynamic> msg) {
  final userManager = Get.find<UserManagementService>();
  final boxIp = userManager.activeUser.value?.deviceIp;
  
  MessageOwner? receiver;
  if (boxIp != null && boxIp.isNotEmpty) {
    receiver = MessageOwner(
      transmission: TransmissionType.udp,
      ip: boxIp,
      port: 53250,
    );
  }
  
  Get.find<DataBridgeService>().send(msg, receiver: receiver);
}

Widget buildBottomIconButton(
  IconData icon, 
  String label, 
  Color color, 
  VoidCallback onTap, {
  double iconSize = 32.0, // Varsayılan 24'ten 32'ye çıkarıldı
  double fontSize = 12.0, // Varsayılan 8'den 12'ye çıkarıldı
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: iconSize),
          const SizedBox(height: 6),
          Text(
            label, 
            style: TextStyle(
              fontSize: fontSize, 
              fontWeight: FontWeight.bold, 
              color: Get.theme.colorScheme.onSurface.withOpacity(0.8)
            )
          ),
        ],
      ),
    ),
  );
}

Widget buildCompactRadio(int value, int groupValue, String label, ValueChanged<int?> onChanged) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Radio<int>(
        value: value, 
        groupValue: groupValue, 
        onChanged: onChanged,
        visualDensity: VisualDensity.comfortable, // Daha ferah
      ),
      Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), // Büyütüldü
    ],
  );
}

Widget buildChkNO(RxBool val, String txt, String helpText, HelpCallback help) {
  final theme = Get.theme;
  return SizedBox(
    width: double.infinity,
    height: 45, // Yükseklik artırıldı
    child: Row(
      children: [
        Obx(
          () => SizedBox(
            width: 40,
            child: Transform.scale(
              scale: 1.3, // Checkbox büyütüldü
              child: Checkbox(
                checkColor: Colors.red,
                activeColor: Colors.white,
                tristate: false,
                value: val.value,
                side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                onChanged: (bool? newValue) {
                  help(helpText);
                  val.value = newValue!;
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => help(helpText),
            child: Obx(() => Text(
              txt,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: val.value 
                  ? const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16) 
                  : TextStyle(color: theme.colorScheme.onSurface, fontSize: 16),
            )),
          ),
        ),
      ],
    ),
  );
}

void showNumberInputDialog(String title, int initialValue, Function(int) onSave) {
  final TextEditingController controller = TextEditingController(text: initialValue.toString());
  Get.defaultDialog(
    title: title,
    backgroundColor: Get.theme.colorScheme.surface,
    titleStyle: TextStyle(color: Get.theme.colorScheme.onSurface),
    content: Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        maxLength: 2,
        autofocus: true,
        style: TextStyle(color: Get.theme.colorScheme.onSurface),
        decoration: const InputDecoration(
          hintText: "0-99 arası sayı girin",
          counterText: "",
        ),
      ),
    ),
    confirm: ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
      onPressed: () {
        int? val = int.tryParse(controller.text);
        if (val != null) {
          onSave(val);
        }
        Get.back();
      },
      child: const Text("TAMAM", style: TextStyle(color: Colors.white)),
    ),
    cancel: OutlinedButton(
      onPressed: () => Get.back(),
      child: const Text("İPTAL"),
    ),
  );
}

Widget buildTimerButton(String label, int value, VoidCallback onTap) {
  final theme = Get.theme;
  return ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
      foregroundColor: theme.colorScheme.onSurface,
      elevation: 0,
      minimumSize: const Size(250, 60), // Genişletildi ve yükseltildi
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
      ),
    ),
    onPressed: onTap,
    child: Text("$label $value", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
  );
}

bool _isFilterWindowOpen = false;

void showFilterWindow(BuildContext context, String label, int id, int insid, int kanal, {bool isMotion = false}) {
  if (_isFilterWindowOpen) return; // hızlı art arda tıklama -- aynı popup iki kez açılmasın
  _isFilterWindowOpen = true;
  final theme = Get.theme;
  // ... (içerik aynı başlangıç)
  final RxBool isLoading = true.obs;
  final RxBool isTimeout = false.obs;
  var g0 = false.obs;
  var g1 = false.obs;
  var g2 = false.obs;
  var g3 = false.obs;
  var g4 = false.obs;
  var g5 = false.obs;
  var g6 = false.obs;
  var g7 = false.obs;
  var hlptxt = "".obs;

  void updateFilter(int stat) {
    g0.value = (stat & 0x01) != 0;
    g1.value = (stat & 0x02) != 0;
    g2.value = (stat & 0x04) != 0;
    g3.value = (stat & 0x08) != 0;
    g4.value = (stat & 0x10) != 0;
    g5.value = (stat & 0x20) != 0;
    g6.value = (stat & 0x40) != 0;
    g7.value = (stat & 0x80) != 0;
  }

  void helpYaz(String? txt) {
    if (txt == null) return;
    hlptxt.value = txt;
    Timer(const Duration(seconds: 10), () => hlptxt.value = "");
  }

  Timer? timeoutTimer;
  void fetchData() {
    isLoading.value = true;
    isTimeout.value = false;
    sendToOutbox({"com": "qfilter", "adr": id, "ins": insid, "kanal": kanal});
    
    timeoutTimer?.cancel();
    timeoutTimer = Timer(const Duration(seconds: 3), () {
      if (isLoading.value) {
        isLoading.value = false;
        isTimeout.value = true;
      }
    });
  }

  fetchData();

  final subscription = Get.find<DataBridgeService>().dataStream.listen((data) {
    final payload = data['full_payload'];
    if (payload is Map && payload['com'] == 'qfilter' && payload['adr'] == id && payload['ins'] == insid) {
      int stat = int.tryParse(payload['filter']?.toString() ?? '0') ?? 0;
      updateFilter(stat);
      isLoading.value = false;
      isTimeout.value = false;
      timeoutTimer?.cancel();
    }
  });

  double hh = MediaQuery.of(context).size.height * 0.50; // Yükseklik artırıldı
  
  Get.dialog(
    AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      title: Text('$label Durumu', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface), textAlign: TextAlign.center),
      content: Obx(() {
        if (isLoading.value) {
          return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
        }
        if (isTimeout.value) {
          return const SizedBox(
            height: 150,
            child: Center(
              child: Text("Cevap gelmedi", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          );
        }
        return Container(
          width: 500, // Genişlik artırıldı
          height: hh,
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.5)),
            borderRadius: const BorderRadius.all(Radius.circular(15.0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Column(
                    children: isMotion
                        ? [
                            buildChkNO(g0, "Occupied", "Oda boşken ilk hareket algılandığında bir kez bilgi gönder — bir 'oturum' başlatır. Oturum devam ederken (Stuck süresi dolmadan) yeni hareket gelirse süre yenilenir ama tekrar Occupied gönderilmez.", helpYaz),
                            buildChkNO(g1, "Vacant", "Son hareketten itibaren 'Zaman' ekranındaki Stuck süresi boyunca hiç hareket tekrarlanmazsa (ya da C.Hold ile iptal edilirse) oturum sona erer ve bir kez bilgi gönderilir.", helpYaz),
                            buildChkNO(g3, "Movement", "Sensör her hareket algıladığında, tekrar eden darbelerde bile, her seferinde bilgi gönder", helpYaz),
                            buildChkNO(g4, "No Movement", "Sensör her hareketsizliğe geçtiğinde, tekrar eden darbelerde bile, her seferinde bilgi gönder", helpYaz),
                          ]
                        : [
                            buildChkNO(g0, "Released", "Tuş Bırakıldığında bilgi gönder", helpYaz),
                            buildChkNO(g1, "Pressed", "Tuşa basıldığında bilgi gönder ", helpYaz),
                            buildChkNO(g2, "Short Press", "Kısa basışta bilgi gönder", helpYaz),
                            buildChkNO(g3, "Double Press", "Çift basışta bilgi gönder", helpYaz),
                            buildChkNO(g4, "Long Press Start", "Uzun Basıldıgında bilgi gönder", helpYaz),
                            buildChkNO(g5, "Long Repeat", "Uzun basılmaya devam süresince bilgi gönder", helpYaz),
                            buildChkNO(g6, "Long Stop", "Uzun basma bittiğinde bilgi gönder", helpYaz),
                            buildChkNO(g7, "Stuct/Free", "Tuş sıkışmasında bilgi gönder", helpYaz),
                          ],
                  ),
                ),
              ),
              Obx(() => hlptxt.value.isNotEmpty ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(hlptxt.value, style: const TextStyle(color: Colors.teal, fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ) : const SizedBox.shrink()),
            ],
          ),
        );
      }),
      actionsPadding: const EdgeInsets.symmetric(vertical: 12),
      actions: [
        Obx(() => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            buildBottomIconButton(Icons.refresh, "Yenile", Colors.blueGrey, () {
              fetchData();
            }, iconSize: 40, fontSize: 15),
            if (!isTimeout.value && !isLoading.value)
              buildBottomIconButton(Icons.check_circle_outline, "Kaydet", Colors.green, () {
                // ... (kaydet mantığı aynı)
                int ff = 0;
                if (g0.value) ff = ff | 0x01;
                if (g1.value) ff = ff | 0x02;
                if (g2.value) ff = ff | 0x04;
                if (g3.value) ff = ff | 0x08;
                if (g4.value) ff = ff | 0x10;
                if (g5.value) ff = ff | 0x20;
                if (g6.value) ff = ff | 0x40;
                if (g7.value) ff = ff | 0x80;
                sendToOutbox({"com": "sfilter", "adr": id, "ins": insid, "kanal": kanal, "val": ff});
                Get.back();
                Get.snackbar("Başarılı", "Filtre ayarları kaydedildi.");
              }, iconSize: 40, fontSize: 15),
            buildBottomIconButton(Icons.cancel_outlined, isTimeout.value ? "Kapat" : "İptal", Colors.red, () {
              Get.back();
            }, iconSize: 40, fontSize: 15),
          ],
        )),
      ],
    ),
  ).then((_) {
    subscription.cancel();
    timeoutTimer?.cancel();
    _isFilterWindowOpen = false;
  });
}

bool _isTimersWindowOpen = false;

void showTimersWindow(BuildContext context, String label, int id, int insid, int kanal, {bool stuckOnly = false, String stuckLabel = "Stuck"}) {
  if (_isTimersWindowOpen) return; // hızlı art arda tıklama -- aynı popup iki kez açılmasın
  _isTimersWindowOpen = true;
  final theme = Get.theme;
  // ... (içerik aynı başlangıç)
  final RxBool isLoading = true.obs;
  final RxBool isTimeout = false.obs;
  var tshort = 0.obs;
  var trepeat = 0.obs;
  var tstuck = 0.obs;

  Timer? timeoutTimer;
  void fetchData() {
    isLoading.value = true;
    isTimeout.value = false;
    sendToOutbox({"com": "qstimer", "adr": id, "ins": insid, "kanal": kanal});
    
    timeoutTimer?.cancel();
    timeoutTimer = Timer(const Duration(seconds: 3), () {
      if (isLoading.value) {
        isLoading.value = false;
        isTimeout.value = true;
      }
    });
  }

  fetchData();

  final subscription = Get.find<DataBridgeService>().dataStream.listen((data) {
    final payload = data['full_payload'];
    if (payload is Map && payload['com'] == 'qstimer' && payload['adr'] == id && payload['ins'] == insid) {
      tshort.value = int.tryParse(payload['short']?.toString() ?? '0') ?? 0;
      trepeat.value = int.tryParse(payload['long']?.toString() ?? payload['repeat']?.toString() ?? '0') ?? 0;
      tstuck.value = int.tryParse(payload['stuck']?.toString() ?? '0') ?? 0;
      isLoading.value = false;
      isTimeout.value = false;
      timeoutTimer?.cancel();
    }
  });

  double hh = MediaQuery.of(context).size.height * 0.45; // Yükseklik artırıldı
  
  Get.dialog(
    AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      title: Text('$label Timerları', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface), textAlign: TextAlign.center),
      content: Obx(() {
        if (isLoading.value) {
          return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
        }
        if (isTimeout.value) {
          return const SizedBox(
            height: 150,
            child: Center(
              child: Text("Cevap gelmedi", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          );
        }
        return Container(
          width: 500, // Genişlik artırıldı
          height: hh,
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.5)),
            borderRadius: const BorderRadius.all(Radius.circular(15.0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 15),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: stuckOnly
                      ? [
                          buildTimerButton(stuckLabel, tstuck.value, () async {
                            showNumberInputDialog(stuckLabel, tstuck.value,(val) => tstuck.value = val);
                          }),
                        ]
                      : [
                          buildTimerButton("Short", tshort.value, () async {
                            showNumberInputDialog("Short Timer", tshort.value, (val) => tshort.value = val);
                          }),
                          buildTimerButton("Long Repeat", trepeat.value, () async {
                            showNumberInputDialog("Repeat Timer", trepeat.value, (val) => trepeat.value = val);
                          }),
                          buildTimerButton(stuckLabel, tstuck.value, () async {
                            showNumberInputDialog(stuckLabel, tstuck.value,(val) => tstuck.value = val);
                          }),
                        ],
                ),
              ),
              const SizedBox(height: 15),
            ],
          ),
        );
      }),
      actionsPadding: const EdgeInsets.symmetric(vertical: 12),
      actions: [
        Obx(() => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            buildBottomIconButton(Icons.refresh, "Yenile", Colors.blueGrey, () {
              fetchData();
            }, iconSize: 40, fontSize: 15),
            if (!isTimeout.value && !isLoading.value)
              buildBottomIconButton(Icons.check_circle_outline, "Kaydet", Colors.green, () {
                sendToOutbox({
                  "com": "sstimer",
                  "adr": id,
                  "ins": insid,
                  "kanal": kanal,
                  "short": tshort.value,
                  "long": trepeat.value,
                  "stuck": tstuck.value,
                });
                Get.back();
                Get.snackbar("Başarılı", "Timer ayarları kaydedildi.");
              }, iconSize: 40, fontSize: 15),
            buildBottomIconButton(Icons.cancel_outlined, isTimeout.value ? "Kapat" : "İptal", Colors.red, () {
              Get.back();
            }, iconSize: 40, fontSize: 15),
          ],
        )),
      ],
    ),
  ).then((_) {
    subscription.cancel();
    timeoutTimer?.cancel();
    _isTimersWindowOpen = false;
  });
}
