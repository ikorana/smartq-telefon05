import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../user/appUser.dart';
import '../../../user/userManagementService.dart';
import '../dashboardController.dart';
import 'groupTimingDialog.dart';
import '../../../main.dart'; // isTablet tespiti için eklendi

class GroupButton extends StatelessWidget {
  final GrpInfo group;
  final Function(int id)? onTap;

  const GroupButton({
    super.key,
    required this.group,
    this.onTap,
  });

  // Seçilebilir 11 İkon (0-10 arası)
  static const List<IconData> groupIcons = [
    Icons.layers,          // 0
    Icons.lightbulb,       // 1
    Icons.ac_unit,         // 2
    Icons.home,            // 3
    Icons.settings,        // 4
    Icons.security,        // 5
    Icons.timer,           // 6
    Icons.favorite,        // 7
    Icons.flash_on,        // 8
    Icons.palette,         // 9
    Icons.weekend,         // 10
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // SABİT BOYUTLU BUTON (85x85)
    return SizedBox(
      width: 85,
      height: 85,
      child: InkWell(
        onTap: () => _showGroupActionDialog(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getIconData(group.icon),
                size: 24,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 4),
              Text(
                group.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGroupActionDialog(BuildContext context) {
    final theme = Theme.of(context);
    final controller = Get.find<DashboardController>();
    final userManager = Get.find<UserManagementService>();
    
    final List<ChannelMenu> menus = userManager.activeUser.value?.channelMenus ?? [];
    
    final List<Map<String, dynamic>> items = [
      {'label': 'all_channels'.tr, 'value': 9},
      ...menus.map((m) => {
        'label': m.name,
        'value': m.channel
      }),
    ];

    bool valueExists = items.any((item) => item['value'] == controller.selectedGroupChannel.value);
    if (!valueExists) {
      controller.selectedGroupChannel.value = 9;
    }

    Get.dialog(
      Dialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        child: SizedBox(
          width: isTablet.value ? Get.width / 2 : null,
          child: Obx(() {
            final currentGroup = userManager.activeGroups.firstWhereOrNull((g) => g.id == group.id) ?? group;
            
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentGroup.name,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(height: 20),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildTopIconButton(
                          context, 
                          Icons.edit_outlined, 
                          'rename'.tr, 
                          theme.colorScheme.primary,
                          () => _showRenameDialog(context)
                        ),
                        _buildTopIconButton(
                          context, 
                          Icons.category_outlined, 
                          'icon_degistir'.tr, 
                          theme.colorScheme.primary,
                          () => _showIconPicker(context)
                        ),
                        _buildTopIconButton(
                          context, 
                          Icons.visibility_off_outlined, 
                          'hide'.tr, 
                          theme.colorScheme.error,
                          () => _confirmHide(context)
                        ),
                      ],
                    ),
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 15),
                      child: Divider(),
                    ),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: controller.selectedGroupChannel.value,
                          isExpanded: true,
                          items: items.map((item) {
                            return DropdownMenuItem<int>(
                              value: item['value'],
                              child: Text(item['label'], style: TextStyle(color: theme.colorScheme.onSurface)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) controller.selectedGroupChannel.value = val;
                          },
                          dropdownColor: theme.scaffoldBackgroundColor,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('brightness'.tr, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 12)),
                            Text("%${((controller.groupPowerValue.value / 254) * 100).toInt()}", 
                              style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Slider(
                          value: controller.groupPowerValue.value,
                          min: 1,
                          max: 254,
                          divisions: 253,
                          onChanged: (val) => controller.groupPowerValue.value = val,
                          onChangeEnd: (val) {
                            controller.groupOn(
                              currentGroup.id, 
                              power: val.toInt(),
                              channel: controller.selectedGroupChannel.value
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactActionButton(
                            context,
                            label: 'open'.tr,
                            icon: Icons.power_settings_new,
                            color: Colors.green,
                            onTap: () {
                              controller.groupOn(
                                currentGroup.id, 
                                power: controller.groupPowerValue.value.toInt(),
                                channel: controller.selectedGroupChannel.value
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCompactActionButton(
                            context,
                            label: 'close'.tr,
                            icon: Icons.power_off,
                            color: Colors.redAccent,
                            onTap: () {
                              controller.groupOff(
                                currentGroup.id,
                                channel: controller.selectedGroupChannel.value
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCompactActionButton(
                            context,
                            label: 'zamanlama'.tr,
                            icon: Icons.access_time,
                            color: Colors.orange,
                            onTap: () {
                              controller.getGroupTiming(currentGroup.id);
                              Get.dialog(
                                GroupTimingDialog(
                                  title: currentGroup.name,
                                  id: currentGroup.id,
                                  getCommand: 'get_grp_time',
                                  onSave: (time1, time2) {
                                    controller.saveGroupTiming(currentGroup.id, time1, time2);
                                  },
                                ),
                              );
                            },
                          ),
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
          }),
        ),
      ),
    );
  }

  Widget _buildTopIconButton(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: color.withOpacity(0.8), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactActionButton(BuildContext context, {required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label, 
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showIconPicker(BuildContext context) {
    final theme = Theme.of(context);
    final UserManagementService userManager = Get.find<UserManagementService>();

    Get.defaultDialog(
      title: 'icon_degistir'.tr,
      titleStyle: TextStyle(color: theme.colorScheme.onSurface),
      backgroundColor: theme.scaffoldBackgroundColor,
      content: SizedBox(
        width: double.maxFinite,
        height: 200,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: groupIcons.length,
          itemBuilder: (context, index) {
            return InkWell(
              onTap: () {
                userManager.updateGroupIcon(group.id, index);
                Get.back();
              },
              child: Container(
                decoration: BoxDecoration(
                  color: group.icon == index ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: group.icon == index ? theme.colorScheme.primary : Colors.transparent,
                  ),
                ),
                child: Icon(groupIcons[index], color: theme.colorScheme.primary),
              ),
            );
          },
        ),
      ),
    );
  }

  void _confirmHide(BuildContext context) {
    final theme = Theme.of(context);
    final UserManagementService userManager = Get.find<UserManagementService>();

    Get.defaultDialog(
      title: 'hide'.tr,
      middleText: 'group_hide_confirm'.tr,
      backgroundColor: theme.scaffoldBackgroundColor,
      textConfirm: 'yes'.tr,
      textCancel: 'no'.tr,
      confirmTextColor: Colors.white,
      buttonColor: Colors.redAccent,
      onConfirm: () {
        userManager.updateGroupIcon(group.id, 11);
        Get.back();
        Get.back();
      },
    );
  }

  void _showRenameDialog(BuildContext context) {
    final theme = Theme.of(context);
    final TextEditingController nameController = TextEditingController(text: group.name);
    final UserManagementService userManager = Get.find<UserManagementService>();

    Get.defaultDialog(
      title: 'rename'.tr,
      backgroundColor: theme.scaffoldBackgroundColor,
      content: Padding(
        padding: const EdgeInsets.all(15),
        child: TextField(
          controller: nameController,
          maxLength: 20,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            counterStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3))),
          ),
        ),
      ),
      onConfirm: () {
        if (nameController.text.isNotEmpty) {
          userManager.updateGroupName(group.id, nameController.text);
          Get.find<DashboardController>().renameGroup(group.id, nameController.text);
          Get.back();
        }
      },
    );
  }

  IconData _getIconData(int iconIndex) {
    if (iconIndex >= 0 && iconIndex < groupIcons.length) {
      return groupIcons[iconIndex];
    }
    return Icons.layers;
  }
}
