import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../user/userManagementService.dart';
import '../user/appUser.dart';
import 'ins_ui_helper.dart';
import 'ins_anahtar.dart';
import 'ins_hareket.dart';
import 'ins_temp.dart';
import 'tool.dart';

// Yerel (DALI olmayan, kanal=10) anahtar/sensör instance'larını, DALI
// AnahtarDevice._showInstancesDialog ile aynı desende ama tek bir cihaz id'sine
// değil "chn == 10" filtresine bağlı olarak listeler.
class _InstanceDisplayInfo {
  final IconData icon;
  final String label;
  _InstanceDisplayInfo(this.icon, this.label);
}

_InstanceDisplayInfo _getInstanceInfo(int type, int filter) {
  switch (type) {
    case 1:
      // filter: 0=Anahtar (momentary tuş), 1=Switch (maintained anahtar)
      return filter == 1
          ? _InstanceDisplayInfo(Icons.toggle_on_outlined, "Switch")
          : _InstanceDisplayInfo(Icons.touch_app_outlined, "Anahtar");
    case 2:
      return _InstanceDisplayInfo(Icons.lightbulb_outline, "Dim Anahtar");
    case 3:
      return _InstanceDisplayInfo(Icons.motion_photos_on_outlined, "Hareket");
    case 4:
      return _InstanceDisplayInfo(Icons.light_mode_outlined, "Işık");
    case 5:
      return _InstanceDisplayInfo(Icons.sensors_outlined, "Genel");
    case 6:
      return _InstanceDisplayInfo(Icons.thermostat_outlined, "Isı");
    default:
      return _InstanceDisplayInfo(Icons.extension_outlined, "Birim");
  }
}

void _handleInstanceTap(InsIntroScn ins) {
  switch (ins.type) {
    case 1:
    case 2:
      showSwitchConfigPopup(ins.adr, ins.chn, ins);
      break;
    case 3:
      showMotionConfigPopup(ins.adr, ins.chn, ins);
      break;
    case 4:
      showLuxPopup(ins);
      break;
    case 5:
      showTempPopup(ins.adr, ins.chn, ins, label: "Genel");
      break;
    case 6:
      showTempPopup(ins.adr, ins.chn, ins, label: "Isı");
      break;
    default:
      Get.snackbar("Bilgi", "Instance ${ins.iadr} (Tip: ${ins.type}) seçildi.");
  }
}

void showLocalSwitchesDialog() {
  final userManager = Get.find<UserManagementService>();
  final theme = Get.theme;

  String getTargetDescription(InsIntroScn ins) {
    if (ins.cm < 0 || ins.cm >= getcommandtype.length) return "";
    String typeStr = getcommandtype[ins.cm].name;
    String nameStr = "";

    switch (ins.cm) {
      case 0: // Lamba
        final dev = userManager.activeDevices.firstWhereOrNull((d) => d.id == ins.cmadr);
        nameStr = dev?.name ?? "Cihaz ${ins.cmadr}";
        break;
      case 1: // Grup
        final grp = userManager.activeGroups.firstWhereOrNull((g) => g.id == ins.cmadr);
        nameStr = grp?.name ?? "Grup ${ins.cmadr}";
        break;
      case 2: // Senaryo
        final scn = userManager.activeScenes.firstWhereOrNull((s) => s.id == ins.cmadr);
        nameStr = scn?.name ?? "Senaryo ${ins.cmadr}";
        break;
      case 3: // Anahtar
        final sw = userManager.activeSwitches.firstWhereOrNull((s) => s.id == ins.cmadr);
        nameStr = sw?.name ?? "Anahtar ${ins.cmadr}";
        break;
    }
    return "$typeStr: $nameStr";
  }

  Get.dialog(
    AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        "Yerel Anahtarlar",
        style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      content: SizedBox(
        width: 600,
        child: Obx(() {
          final instances = userManager.activeInsIntroList.where((ins) => ins.chn == 10 && ins.act == 1).toList();

          if (instances.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                "Yerel anahtar bulunamadı.",
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
              ),
            );
          }

          return GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.8,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemCount: instances.length,
            itemBuilder: (context, index) {
              final ins = instances[index];
              final info = _getInstanceInfo(ins.type, ins.filter);
              final bool isEnabled = ins.act == 1;

              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.surface,
                  foregroundColor: theme.colorScheme.primary,
                  elevation: 3,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
                  ),
                ),
                onPressed: () => _handleInstanceTap(ins),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Icon(info.icon, size: 40),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${info.label} ${ins.adr}",
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isEnabled ? "Aktif" : "Pasif",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isEnabled ? Colors.green : Colors.redAccent,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            getTargetDescription(ins),
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }),
      ),
      actionsPadding: const EdgeInsets.symmetric(vertical: 10),
      actions: [
        buildBottomIconButton(Icons.cancel_outlined, "Kapat", Colors.red, () {
          Get.back();
        }, iconSize: 40, fontSize: 15),
      ],
    ),
  );
}
