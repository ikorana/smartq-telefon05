import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../dashboardController.dart';

class PowerActionDialog extends StatelessWidget {
  const PowerActionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = Get.find<DashboardController>();

    return Dialog(
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'system_power'.tr,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 20),
            
            // Parlaklık Slider'ı (Sistem Geneli)
            Obx(() => Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('brightness'.tr, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 12)),
                    Text("%${((controller.systemPowerValue.value / 254) * 100).toInt()}", 
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: controller.systemPowerValue.value,
                  min: 1,
                  max: 254,
                  divisions: 253,
                  onChanged: (val) => controller.systemPowerValue.value = val,
                  onChangeEnd: (val) => controller.systemOpen(power: val.toInt()),
                ),
              ],
            )),

            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPowerButton(
                  context,
                  label: 'all_open'.tr,
                  icon: Icons.power_settings_new,
                  color: Colors.green,
                  onTap: () {
                    controller.systemOpen();
                  },
                ),
                _buildPowerButton(
                  context,
                  label: 'all_close'.tr,
                  icon: Icons.power_off,
                  color: Colors.redAccent,
                  onTap: () {
                    controller.systemClose();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Get.back(),
              child: Text('close'.tr, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerButton(BuildContext context, {required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 100, // Boyut küçültüldü (110 -> 100)
        padding: const EdgeInsets.symmetric(vertical: 12), // Padding küçültüldü (20 -> 12)
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3), width: 1.2),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26), // İkon küçültüldü (32 -> 26)
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11), // Font küçültüldü (13 -> 11)
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
