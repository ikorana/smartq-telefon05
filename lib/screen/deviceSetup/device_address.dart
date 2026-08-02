import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../user/appUser.dart';
import 'deviceSetupController.dart';

class DeviceAddressHelper {
  static void showChannelSelection(BuildContext context, DeviceSetupController controller) {
    final theme = Theme.of(context);
    final user = controller.currentUser;
    final List<ChannelMenu> menus = user?.channelMenus ?? [];

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: theme.colorScheme.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
            ),
            Text('select_channel'.tr, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 20),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: menus.map((menu) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(Icons.sensors, color: theme.colorScheme.primary, size: 20),
                      ),
                      title: Text(menu.name, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w500)),
                      trailing: Icon(Icons.arrow_forward_ios, size: 14, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                      onTap: () {
                        Get.back();
                        showAddressingOptions(context, menu.channel);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  static void showAddressingOptions(BuildContext context, int channel) {
    final theme = Theme.of(context);
    final controller = Get.find<DeviceSetupController>();

    Get.dialog(
      AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('address_devices'.tr, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogButton(context, 'address_all_devices'.tr, Icons.format_list_numbered, () {
              controller.sendGeneralCommand({
                "com": "adresle",
                "kanal": channel,
                "value": 1
              });
              Get.back();
            }),
            const SizedBox(height: 12),
            _buildDialogButton(context, 'address_unaddressed'.tr, Icons.add_link, () {
              controller.sendGeneralCommand({
                "com": "adresle",
                "kanal": channel,
                "value": 2
              });
              Get.back();
            }),
            const SizedBox(height: 12),
            _buildDialogButton(context, 'change_address'.tr, Icons.published_with_changes, () {
              // TODO: Implement Address Change
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('vazgec'.tr),
          ),
        ],
      ),
    );
  }

  static Widget _buildDialogButton(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          foregroundColor: theme.colorScheme.primary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
