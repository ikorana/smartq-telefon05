import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../user/appUser.dart';
import '../../../user/userManagementService.dart';
import '../dashboardController.dart';
import 'groupTimingDialog.dart';
import '../../../main.dart'; // isTablet tespiti için eklendi

class SenaryoButton extends StatelessWidget {
  final ScnInfo scene;
  final Function(int id)? onTap;

  const SenaryoButton({
    super.key,
    required this.scene,
    this.onTap,
  });

  // Senaryolar için ikon listesi
  static const List<IconData> sceneIcons = [
    Icons.auto_awesome,    // 0
    Icons.wb_sunny,        // 1
    Icons.bedtime,         // 2
    Icons.movie,           // 3
    Icons.coffee,          // 4
    Icons.work,            // 5
    Icons.party_mode,      // 6
    Icons.meeting_room,    // 7
    Icons.directions_run,  // 8
    Icons.home,            // 9
    Icons.lock,            // 10
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // SABİT BOYUTLU BUTON (85x85)
    return SizedBox(
      width: 85,
      height: 85,
      child: InkWell(
        onTap: () => _showScenarioActionPopup(context),
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
                _getIconData(scene.icon),
                size: 24,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 4),
              Text(
                scene.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showScenarioActionPopup(BuildContext context) {
    final theme = Theme.of(context);
    final controller = Get.find<DashboardController>();
    final userManager = Get.find<UserManagementService>();

    final int totalChannels = userManager.activeUser.value?.totalChannels ?? 1;
    
    final List<Map<String, dynamic>> items = [
      {'label': 'all_channels'.tr, 'value': 9},
      ...List.generate(totalChannels, (index) => {
        'label': '${'channel'.tr} ${index + 1}',
        'value': index + 1
      }),
    ];

    Get.dialog(
      Dialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        child: SizedBox(
          width: isTablet.value ? Get.width / 2 : null,
          child: Obx(() {
            // Reaktif güncellemeler için senaryoyu bulalım
            final currentScene = userManager.activeScenes.firstWhereOrNull((s) => s.id == scene.id) ?? scene;

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentScene.name,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(height: 20),

                    // TOPBAR (İsim Değiştir, İkon Değiştir, Gizle)
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

                    // KANAL SEÇİM COMBOBOX
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: controller.selectedScenarioChannel.value,
                          items: items.map((item) {
                            return DropdownMenuItem<int>(
                              value: item['value'],
                              child: Text(item['label'], style: TextStyle(color: theme.colorScheme.onSurface)),
                            );
                          }).toList(),
                          onChanged: (int? newValue) {
                            if (newValue != null) controller.selectedScenarioChannel.value = newValue;
                          },
                          dropdownColor: theme.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            context,
                            label: 'turn_off_all'.tr, 
                            icon: Icons.lightbulb_outline,
                            color: Colors.grey,
                            onTap: () {
                              controller.allLightsOff(currentScene.id, channel: controller.selectedScenarioChannel.value);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildActionButton(
                            context,
                            label: 'apply_to_all_lights'.tr,
                            icon: Icons.done_all,
                            color: Colors.blueAccent,
                            onTap: () {
                              controller.applyToAllLights(currentScene.id, channel: controller.selectedScenarioChannel.value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            context,
                            label: 'zamanlama'.tr,
                            icon: Icons.schedule,
                            color: Colors.orange,
                            onTap: () {
                              controller.getScenarioTiming(currentScene.id);
                              Get.dialog(
                                GroupTimingDialog(
                                  title: currentScene.name,
                                  id: currentScene.id,
                                  getCommand: 'get_scn_time',
                                  onSave: (time1, time2) {
                                    controller.saveScenarioTiming(currentScene.id, time1, time2);
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildActionButton(
                            context,
                            label: 'apply_to_group'.tr,
                            icon: Icons.group_work,
                            color: theme.colorScheme.primary,
                            onTap: () {
                              if (controller.selectedGroupIdForScene.value != null) {
                                controller.applyToGroup(
                                  currentScene.id,
                                  controller.selectedGroupIdForScene.value!,
                                  channel: controller.selectedScenarioChannel.value,
                                );
                              } else {
                                Get.snackbar('Sistem', 'select_group_hint'.tr);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "groups".tr,
                        style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Obx(() {
                      final visibleGroups = controller.groups.where((g) => g.icon != 11).toList();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            hint: Text("Grup Seçin", style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                            value: controller.selectedGroupIdForScene.value,
                            items: visibleGroups.map((group) {
                              return DropdownMenuItem<int>(
                                value: group.id,
                                child: Text(group.name, style: TextStyle(color: theme.colorScheme.onSurface)),
                              );
                            }).toList(),
                            onChanged: (int? newValue) {
                              controller.selectGroupForScene(newValue);
                            },
                            dropdownColor: theme.scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 15),
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

  Widget _buildActionButton(BuildContext context, {required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
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
          itemCount: sceneIcons.length,
          itemBuilder: (context, index) {
            return InkWell(
              onTap: () {
                userManager.updateSceneIcon(scene.id, index);
                Get.back();
              },
              child: Container(
                decoration: BoxDecoration(
                  color: scene.icon == index ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: scene.icon == index ? theme.colorScheme.primary : Colors.transparent,
                  ),
                ),
                child: Icon(sceneIcons[index], color: theme.colorScheme.primary),
              ),
            );
          },
        ),
      ),
    );
  }

  void _confirmHide(BuildContext context) {
    final UserManagementService userManager = Get.find<UserManagementService>();

    Get.defaultDialog(
      title: 'hide'.tr,
      middleText: 'group_hide_confirm'.tr,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      textConfirm: 'yes'.tr,
      textCancel: 'no'.tr,
      confirmTextColor: Colors.white,
      buttonColor: Colors.redAccent,
      onConfirm: () {
        userManager.updateSceneIcon(scene.id, 11);
        Get.back(); // Dialog'u kapat
        Get.back(); // Ana popup'ı kapat
      },
    );
  }

  void _showRenameDialog(BuildContext context) {
    final theme = Theme.of(context);
    final TextEditingController nameController = TextEditingController(text: scene.name);
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
          userManager.updateSceneName(scene.id, nameController.text);
          Get.find<DashboardController>().renameScene(scene.id, nameController.text);
          Get.back();
        }
      },
    );
  }

  Widget _buildContextItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Get.theme.colorScheme.primary),
      title: Text(label),
      onTap: onTap,
    );
  }

  IconData _getIconData(int iconIndex) {
    if (iconIndex >= 0 && iconIndex < sceneIcons.length) {
      return sceneIcons[iconIndex];
    }
    return Icons.auto_awesome;
  }
}
