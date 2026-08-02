import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../comminication/comminicationBadge.dart';
import '../../devices/base.dart';
import '../../user/appUser.dart';
import '../../user/userManagementService.dart';
import '../userSelection/userSelectionUI.dart';
import 'deviceSetupController.dart';
import 'device_address.dart';

class DeviceSetupPage extends GetView<DeviceSetupController> {
  const DeviceSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<DeviceSetupController>()) {
      Get.put(DeviceSetupController());
    }

    final theme = Theme.of(context);
    final UserManagementService userManager = Get.find<UserManagementService>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'device_setup'.tr,
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          const ComminicationBadge(),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          _buildTopBar(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: Obx(() {
                final category = controller.selectedCategory.value;
                if (category == SetupCategory.none) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 100),
                      child: Column(
                        children: [
                          Icon(Icons.settings_suggest_outlined, size: 80, color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                          const SizedBox(height: 20),
                          Text('select_category_hint'.tr, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                        ],
                      ),
                    ),
                  );
                }
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 5, bottom: 15),
                      child: Text(
                        _getCategoryTitle(category),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                      ),
                    ),
                    _buildCategoryContent(context, userManager),
                  ],
                );
              }),
            ),
          ),
          _buildTerminal(context),
        ],
      ),
    );
  }

  Widget _buildTerminal(BuildContext context) {
    final theme = Theme.of(context);
    final ScrollController scrollController = ScrollController(); 

    void scrollToBottom() {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }

    return Container(
      height: Get.height / 3, 
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.terminal, size: 16, color: Colors.greenAccent),
                    const SizedBox(width: 8),
                    Text('system_log'.tr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                  ],
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.delete_sweep_outlined, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  onPressed: () => controller.clearTerminal(),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Obx(() {
                scrollToBottom();
                return ListView.builder(
                  controller: scrollController,
                  itemCount: controller.terminalLogs.length,
                  itemBuilder: (context, index) {
                    final log = controller.terminalLogs[index];
                    return Text(
                      log,
                      style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 120,
      width: double.infinity,
      color: theme.scaffoldBackgroundColor,
      child: Obx(() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTopBarItem(
            context, 
            Icons.meeting_room_outlined, 
            'room_management'.tr, 
            SetupCategory.room,
            controller.selectedCategory.value == SetupCategory.room
          ),
          _buildTopBarItem(
            context, 
            Icons.developer_board, 
            'intro'.tr, 
            SetupCategory.intro,
            controller.selectedCategory.value == SetupCategory.intro
          ),
          _buildTopBarItem(
            context, 
            Icons.settings_input_component_outlined, 
            'device_management'.tr, 
            SetupCategory.device,
            controller.selectedCategory.value == SetupCategory.device
          ),
          _buildTopBarItem(
            context, 
            Icons.build_circle_outlined, 
            'system_tools'.tr, 
            SetupCategory.system,
            controller.selectedCategory.value == SetupCategory.system
          ),
          _buildTopBarActionItem(
            context, 
            Icons.person_outline, 
            'profile_management'.tr, 
            () => Get.to(() => const UserSelectionPage())
          ),
        ],
      )),
    );
  }

  Widget _buildTopBarItem(BuildContext context, IconData icon, String label, SetupCategory category, bool isSelected) {
    final theme = Theme.of(context);
    final bool isAdmin = controller.isAdmin;
    final bool isSystem = category == SetupCategory.system;
    final bool isEnabled = isAdmin || isSystem;
    
    final color = isSelected 
        ? theme.colorScheme.primary 
        : (isEnabled ? Colors.white : Colors.white.withOpacity(0.3));
    
    return Expanded(
      child: InkWell(
        onTap: isEnabled ? () => controller.changeCategory(category) : null,
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                shape: BoxShape.circle,
                border: isSelected ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)) : null,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.0,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBarActionItem(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final color = Colors.white;
    
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.0,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryTitle(SetupCategory category) {
    switch (category) {
      case SetupCategory.room: return 'room_management'.tr;
      case SetupCategory.intro: return 'intro'.tr;
      case SetupCategory.device: return 'device_management'.tr;
      case SetupCategory.system: return 'system_tools'.tr;
      case SetupCategory.none: return '';
    }
  }

  Widget _buildCategoryContent(BuildContext context, UserManagementService userManager) {
    final category = controller.selectedCategory.value;
    
    if (category == SetupCategory.room) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _buildMenuButton(context, 'add_room'.tr, Icons.add_business_outlined, () => _showAddRoomDialog(context), false),
          _buildMenuButton(context, 'add_switch'.tr, Icons.add_circle_outline, () => _showAddSwitchDialog(context), false),
          
          _buildMenuButton(context, 'get_rooms'.tr, Icons.list_alt, () => controller.sendGetRoom(), false),
          _buildMenuButton(context, 'get_switches'.tr, Icons.keyboard_alt_outlined, () => controller.getSwitches(), false),
          
          _buildMenuButton(context, 'delete_room'.tr, Icons.delete_forever_outlined, () => _openDeleteRoomSelection(context), false, isWarning: true),
          _buildMenuButton(context, 'delete_switch'.tr, Icons.remove_circle_outline, () => _openDeleteSwitchSelection(context, userManager), false, isWarning: true),
        ],
      );
    }

    List<Widget> buttons = [];
    if (category == SetupCategory.intro) {
      buttons = [
        _buildMenuButton(context, 'group_intro'.tr, Icons.groups_outlined, () => controller.groupIntro(), false),
        _buildMenuButton(context, 'scenario_intro'.tr, Icons.settings_suggest_outlined, () => controller.scenarioIntro(), false),
        _buildMenuButton(context, 'sub_device_intro'.tr, Icons.account_tree_outlined, () => controller.sendGeneralCommand({"com": "ins_intro"}), false),
      ];
    } else if (category == SetupCategory.device) {
      buttons = [
        _buildMenuButton(context, 'device_list'.tr, Icons.format_list_bulleted, () => _showDeviceListSheet(context), false),
        _buildMenuButton(context, 'get_devices'.tr, Icons.get_app, () => _showGetDeviceOptions(context), false),
        _buildMenuButton(context, 'search_devices'.tr, Icons.search, () => _showSearchOptions(context), false),
        _buildMenuButton(context, 'address_devices'.tr, Icons.format_list_numbered, () => DeviceAddressHelper.showChannelSelection(context, controller), false),
        _buildMenuButton(context, 'MODBUS Cihaz Adresle', Icons.settings_ethernet, () => {}, false),
        _buildMenuButton(context, 'clear_device_list'.tr, Icons.layers_clear_outlined, () => _showClearListConfirm(context), false, isWarning: true),
        _buildMenuButton(context, 'Lokal Cihazları SİL', Icons.delete_sweep_outlined, () => _showClearLocalDevicesConfirm(context), false, isWarning: true),
      ];
    } else if (category == SetupCategory.system) {
      buttons = [
        _buildMenuButton(context, 'get_version'.tr, Icons.info_outline, () => controller.getVersion(), true),
        _buildMenuButton(context, 'clear_terminal'.tr, Icons.cleaning_services_outlined, () => controller.clearTerminal(), true),
        _buildMenuButton(context, 'auto_setup'.tr, Icons.auto_mode, () => _showAutoSetupConfirm(context), true),
        _buildMenuButton(context, 'show_hidden_groups'.tr, Icons.visibility_outlined, () => _showHiddenGroupsDialog(context, userManager), true),
        _buildMenuButton(context, 'show_hidden_scenarios'.tr, Icons.auto_awesome_outlined, () => _showHiddenScenariosDialog(context, userManager), true),
        _buildMenuButton(context, 'show_hidden_devices'.tr, Icons.devices_other_outlined, () => _showHiddenDevicesDialog(context, userManager), true),
        _buildMenuButton(context, 'Normal Mod Ayarları', Icons.home_outlined, () => {}, true),
        _buildMenuButton(context, 'Evden Çıkış Modu Ayarları', Icons.exit_to_app, () => {}, true),
      ];
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: buttons,
    );
  }

  Widget _buildMenuButton(BuildContext context, String label, IconData icon, VoidCallback onTap, bool isSystemAction, {bool isWarning = false, bool isFullWidth = false}) {
    final theme = Theme.of(context);
    final bool isAdmin = controller.isAdmin;
    final bool isSystemAction_ = isAdmin || isSystemAction;
    
    Color color = isWarning ? Colors.redAccent : theme.colorScheme.primary;
    if (!isSystemAction_) color = theme.colorScheme.onSurface.withValues(alpha: 0.4);

    return InkWell(
      onTap: isSystemAction_ ? onTap : null,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: isFullWidth ? double.infinity : (Get.width - 42) / 2, 
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10), 
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            color.withValues(alpha: 0.08),
            theme.colorScheme.surface,
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: !isSystemAction_ ? null : [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _showAutoSetupConfirm(BuildContext context) {
    final theme = Theme.of(context);
    Get.defaultDialog(
      title: 'attention'.tr,
      middleText: 'auto_setup_confirm_msg'.tr,
      textConfirm: 'yes'.tr,
      textCancel: 'vazgec'.tr,
      confirmTextColor: Colors.white,
      buttonColor: theme.colorScheme.primary,
      onConfirm: () {
        Get.back();
        controller.startAutoSetup();
      },
    );
  }

  void _showClearLocalDevicesConfirm(BuildContext context) {
    final theme = Theme.of(context);
    Get.defaultDialog(
      title: 'attention'.tr,
      middleText: 'Bu işlem cihaz listesini, anahtarları ve alt cihaz bilgilerini telefon hafızasından kalıcı olarak SİLECEKTİR. Emin misiniz?',
      backgroundColor: theme.scaffoldBackgroundColor,
      textConfirm: 'yes'.tr,
      textCancel: 'vazgec'.tr,
      confirmTextColor: Colors.white,
      buttonColor: Colors.redAccent,
      onConfirm: () {
        Get.back();
        controller.clearLocalDevices();
      },
    );
  }

  void _showDeviceListSheet(BuildContext context) {
    final theme = Theme.of(context);
    
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(20, 25, 20, 10),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: theme.colorScheme.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('device_list'.tr, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                IconButton(onPressed: () => Get.back(), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: Obx(() => _buildActionHeaderButton(
                    context, 
                    'turn_all_on'.tr, 
                    Icons.light_mode, 
                    Colors.orangeAccent, 
                    controller.isAllOnLoading.value,
                    () => controller.turnAllOn()
                  )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Obx(() => _buildActionHeaderButton(
                    context, 
                    'turn_all_off'.tr, 
                    Icons.dark_mode, 
                    Colors.blueGrey, 
                    controller.isAllOffLoading.value,
                    () => controller.turnAllOff()
                  )),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Obx(() {
                final sortedDevices = controller.sortedActiveDevices;
                if (sortedDevices.isEmpty) {
                  return Center(child: Text('no_device_found'.tr));
                }
                return ListView.builder(
                  itemCount: sortedDevices.length,
                  itemBuilder: (context, index) {
                    final device = sortedDevices[index];
                    return _buildDeviceCard(context, device);
                  },
                );
              }),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildActionHeaderButton(BuildContext context, String label, IconData icon, Color color, bool isLoading, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: isLoading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        disabledBackgroundColor: color.withValues(alpha: 0.5),
      ),
      child: isLoading 
        ? const SizedBox(
            height: 20, 
            width: 20, 
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, BaseDevice device) {
    final theme = Theme.of(context);
    final UserManagementService userManager = Get.find<UserManagementService>();
    final devKey = "${device.id}_${device.channel}";
    
    return Obx(() {
      final isSelected = controller.selectedDeviceKey.value == devKey;
      final room = userManager.activeRooms.firstWhereOrNull((r) => r.id == device.roomId);
      final roomName = (device.roomId == 255 || room == null) ? 'unassigned_room'.tr : room.name;
      final isHidden = device.ico == 11;
      
      String assignedSwitchName = "";
      if (device.logicButtonId != 255) {
        final sw = userManager.activeSwitches.firstWhereOrNull((s) => s.id == device.logicButtonId);
        if (sw != null) {
          assignedSwitchName = sw.name;
        }
      }

      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.05) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => controller.toggleDeviceSelection(device.id, device.channel),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: [
                  if (assignedSwitchName.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 2, top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${'switch_label'.tr}: $assignedSwitchName",
                            style: TextStyle(
                              fontSize: 9, 
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.primary.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          "${device.id}",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.name ?? 'lamp'.tr, 
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)
                            ),
                            Text(roomName, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                          ],
                        ),
                      ),
                      if (!isSelected)
                        _buildCompactIdentifyButton(context, device, devKey),
                    ],
                  ),
                ],
              ),
            ),

            if (isSelected) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSmallIconButton(
                    context, 
                    Icons.lightbulb, 
                    'turn_on'.tr, 
                    Colors.orangeAccent, 
                    controller.buttonLoadingStates["${devKey}_on"] ?? false,
                    () => controller.runDebouncedAction("${devKey}_on", () => controller.turnDeviceOn(device.id, device.channel))
                  ),
                  _buildSmallIconButton(
                    context, 
                    Icons.lightbulb_outline, 
                    'turn_off'.tr, 
                    Colors.blueGrey, 
                    controller.buttonLoadingStates["${devKey}_off"] ?? false,
                    () => controller.runDebouncedAction("${devKey}_off", () => controller.turnDeviceOff(device.id, device.channel))
                  ),
                  _buildSmallIconButton(
                    context, 
                    Icons.fingerprint, 
                    'identify'.tr, 
                    theme.colorScheme.primary, 
                    controller.buttonLoadingStates["${devKey}_id"] ?? false,
                    () => controller.runDebouncedAction("${devKey}_id", () => controller.identifyDevice(device.id, device.channel))
                  ),
                  _buildSmallIconButton(
                    context, 
                    Icons.edit_note, 
                    'rename'.tr, 
                    theme.colorScheme.primary, 
                    controller.buttonLoadingStates["${devKey}_ren"] ?? false,
                    () => controller.runDebouncedAction("${devKey}_ren", () => _showRenameDialog(context, device))
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSmallIconButton(
                    context, 
                    Icons.meeting_room_outlined, 
                    'change_room'.tr, 
                    theme.colorScheme.primary, 
                    controller.buttonLoadingStates["${devKey}_room"] ?? false,
                    () => controller.runDebouncedAction("${devKey}_room", () => _showRoomSelectionSheet(context, device))
                  ),
                  _buildSmallIconButton(
                    context, 
                    isHidden ? Icons.visibility_off : Icons.visibility, 
                    'hide'.tr, 
                    isHidden ? Colors.redAccent : theme.colorScheme.primary, 
                    false,
                    () {
                      userManager.updateDeviceIcon(device.id, device.channel, isHidden ? 0 : 11);
                    }
                  ),
                  _buildSmallIconButton(
                    context, 
                    Icons.settings_remote, 
                    'switch_label'.tr, 
                    theme.colorScheme.primary, 
                    false,
                    () => _showSwitchSelectionSheet(context, device)
                  ),
                  _buildSmallIconButton(
                    context, 
                    Icons.groups_outlined, 
                    'group_label'.tr, 
                    theme.colorScheme.primary, 
                    false,
                    () {}
                  ),
                  _buildSmallIconButton(
                    context, 
                    Icons.save, 
                    'save'.tr, 
                    Colors.green, 
                    false,
                    () {
                      controller.saveDeviceSettings(device);
                      final user = userManager.activeUser.value;
                      if (user != null) {
                        user.devices = jsonEncode(user.deviceList.map((d) => d.toMap()).toList());
                        userManager.saveOrUpdateUser(user);
                        Get.snackbar('success'.tr, 'settings_saved_to_box'.tr);
                      }
                    }
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildCompactIdentifyButton(BuildContext context, BaseDevice device, String devKey) {
    final theme = Theme.of(context);
    final isLoading = controller.buttonLoadingStates["${devKey}_id"] ?? false;
    
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: isLoading 
        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary))
        : Icon(Icons.fingerprint, color: theme.colorScheme.primary, size: 24),
      onPressed: isLoading ? null : () => controller.runDebouncedAction("${devKey}_id", () => controller.identifyDevice(device.id, device.channel)),
    );
  }

  Widget _buildSmallIconButton(BuildContext context, IconData icon, String label, Color color, bool isLoading, VoidCallback onTap) {
    final theme = Theme.of(context);
    final bool isAdmin = controller.isAdmin;
    
    return InkWell(
      onTap: (isAdmin && !isLoading) ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Opacity(
          opacity: isAdmin ? 1.0 : 0.4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 22,
                width: 22,
                child: isLoading 
                  ? CircularProgressIndicator(strokeWidth: 2, color: color)
                  : Icon(icon, size: 22, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                label, 
                style: TextStyle(
                  fontSize: 10, 
                  fontWeight: FontWeight.w600, 
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7)
                )
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, BaseDevice device) {
    final theme = Theme.of(context);
    final TextEditingController nameController = TextEditingController(text: device.name);
    final UserManagementService userManager = Get.find<UserManagementService>();

    Get.defaultDialog(
      title: 'rename'.tr,
      titleStyle: TextStyle(color: theme.colorScheme.onSurface),
      backgroundColor: theme.scaffoldBackgroundColor,
      content: Padding(
        padding: const EdgeInsets.all(15),
        child: TextField(
          controller: nameController,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            labelText: 'device_name'.tr,
            counterStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            labelStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3))),
          ),
        ),
      ),
      cancel: OutlinedButton(
        onPressed: () => Get.back(), 
        child: Text('vazgec'.tr, style: TextStyle(color: theme.colorScheme.primary))
      ),
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary),
        onPressed: () {
          if (nameController.text.isNotEmpty) {
            userManager.updateDeviceName(device.id, device.channel, nameController.text);
            Get.back();
          }
        },
        child: Text('ok'.tr, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  void _showRoomSelectionSheet(BuildContext context, BaseDevice device) {
    final theme = Theme.of(context);
    final UserManagementService userManager = Get.find<UserManagementService>();

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
            Text('change_room'.tr, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 20),
            Flexible(
              child: Obx(() => ListView.builder(
                shrinkWrap: true,
                itemCount: userManager.activeRooms.length,
                itemBuilder: (context, index) {
                  final room = userManager.activeRooms[index];
                  final isSelected = device.roomId == room.id;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(15),
                      border: isSelected ? Border.all(color: theme.colorScheme.primary) : null,
                    ),
                    child: ListTile(
                      leading: Icon(Icons.meeting_room, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      title: Text(room.name, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      trailing: isSelected ? Icon(Icons.check_circle, color: theme.colorScheme.primary) : null,
                      onTap: () {
                        userManager.updateDeviceRoom(device.id, device.channel, room.id);
                        Get.back();
                      },
                    ),
                  );
                },
              )),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showSwitchSelectionSheet(BuildContext context, BaseDevice device) {
    final theme = Theme.of(context);
    final UserManagementService userManager = Get.find<UserManagementService>();
    
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
            Text('get_switches'.tr, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 20),
            Flexible(
              child: Obx(() {
                final switches = userManager.activeSwitches.where((s) => s.type == 0).toList();
                
                if (switches.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text('no_device_found'.tr),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: switches.length,
                  itemBuilder: (context, index) {
                    final sw = switches[index];
                    final isSelected = device.logicButtonId == sw.id;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(15),
                        border: isSelected ? Border.all(color: theme.colorScheme.primary) : null,
                    ),
                      child: ListTile(
                        leading: Icon(Icons.settings_remote, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                        title: Text(sw.name, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        trailing: isSelected ? Icon(Icons.check_circle, color: theme.colorScheme.primary) : null,
                        onTap: () {
                          device.logicButtonId = sw.id;
                          userManager.activeDevices.refresh();
                          Get.back();
                        },
                      ),
                    );
                  },
                );
              }),
            ),
            ListTile(
              leading: const Icon(Icons.link_off, color: Colors.red),
              title: Text('delete_switch'.tr, style: const TextStyle(color: Colors.red)),
              onTap: () {
                device.logicButtonId = 255;
                userManager.activeDevices.refresh();
                Get.back();
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showClearListConfirm(BuildContext context) {
    final theme = Theme.of(context);
    Get.defaultDialog(
      title: 'attention'.tr,
      middleText: 'clear_device_list_confirm'.tr,
      backgroundColor: theme.scaffoldBackgroundColor,
      textConfirm: 'yes'.tr,
      textCancel: 'vazgec'.tr,
      onConfirm: () {
        Get.back();
        _showChannelSelectionForClear(context);
      },
    );
  }

  void _showChannelSelectionForClear(BuildContext context) {
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
            Text('select_channel_to_clear'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 20),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ...menus.map((menu) {
                    return _buildSearchOptionTile(
                      context,
                      title: menu.name,
                      icon: Icons.delete_sweep_outlined,
                      onTap: () {
                        controller.clearDeviceList(menu.channel);
                        Get.back();
                      },
                    );
                  }),
                  _buildSearchOptionTile(
                    context,
                    title: 'clear_all'.tr,
                    icon: Icons.delete_forever,
                    onTap: () {
                      controller.clearDeviceList(255); 
                      Get.back();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHiddenGroupsDialog(BuildContext context, UserManagementService userManager) {
    final theme = Theme.of(context);
    final hiddenGroups = userManager.activeGroups.where((g) => g.icon == 11).toList();

    Get.defaultDialog(
      title: 'show_hidden_groups'.tr,
      titleStyle: TextStyle(color: theme.colorScheme.onSurface),
      backgroundColor: theme.scaffoldBackgroundColor,
      content: SizedBox(
        width: double.maxFinite,
        child: hiddenGroups.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: Text('no_room_found'.tr, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: hiddenGroups.map((group) {
                  return ListTile(
                    leading: Icon(Icons.visibility_off, color: theme.colorScheme.primary),
                    title: Text(group.name, style: TextStyle(color: theme.colorScheme.onSurface)),
                    trailing: TextButton(
                      onPressed: () {
                        Get.back();
                      },
                      child: Text('yes'.tr),
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }

  void _showHiddenScenariosDialog(BuildContext context, UserManagementService userManager) {
    final theme = Theme.of(context);
    final hiddenScenes = userManager.activeScenes.where((s) => s.icon == 11).toList();

    Get.defaultDialog(
      title: 'show_hidden_scenarios'.tr,
      titleStyle: TextStyle(color: theme.colorScheme.onSurface),
      backgroundColor: theme.scaffoldBackgroundColor,
      content: SizedBox(
        width: double.maxFinite,
        child: hiddenScenes.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: Text('no_scenes_found'.tr, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: hiddenScenes.map((scene) {
                  return ListTile(
                    leading: Icon(Icons.visibility_off, color: theme.colorScheme.primary),
                    title: Text(scene.name, style: TextStyle(color: theme.colorScheme.onSurface)),
                    trailing: TextButton(
                      onPressed: () {
                        Get.back();
                      },
                      child: Text('yes'.tr),
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }

  void _showHiddenDevicesDialog(BuildContext context, UserManagementService userManager) {
    final theme = Theme.of(context);
    final hiddenDevices = userManager.activeDevices.where((d) => d.ico == 11).toList();

    Get.defaultDialog(
      title: 'show_hidden_devices'.tr,
      titleStyle: TextStyle(color: theme.colorScheme.onSurface),
      backgroundColor: theme.scaffoldBackgroundColor,
      content: SizedBox(
        width: double.maxFinite,
        child: hiddenDevices.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: Text('no_device_found'.tr, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: hiddenDevices.map((device) {
                  return ListTile(
                    leading: Icon(Icons.visibility_off, color: theme.colorScheme.primary),
                    title: Text(device.name ?? 'lamp'.tr, style: TextStyle(color: theme.colorScheme.onSurface)),
                    trailing: TextButton(
                      onPressed: () {
                        userManager.updateDeviceIcon(device.id, device.channel, 0);
                        Get.back();
                      },
                      child: Text('yes'.tr),
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }

  void _showSearchOptions(BuildContext context) {
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
            Text('search_devices'.tr, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 20),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ...menus.map((menu) {
                    return _buildSearchOptionTile(
                      context,
                      title: menu.name,
                      icon: Icons.sensors,
                      onTap: () {
                        Get.back();
                        controller.startAdvancedSearch(menu.channel);
                      },
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showGetDeviceOptions(BuildContext context) {
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
            Text('get_devices'.tr, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 20),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ...menus.map((menu) {
                    return _buildSearchOptionTile(
                      context,
                      title: menu.name,
                      icon: Icons.sensors,
                      onTap: () {
                        Get.back();
                        controller.fetchDevicesByType(menu.channel);
                      },
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchOptionTile(BuildContext context, {required String title, required IconData icon, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(icon, color: theme.colorScheme.primary, size: 20),
        ),
        title: Text(title, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
        onTap: onTap,
      ),
    );
  }

  void _showAddRoomDialog(BuildContext context) {
    final theme = Theme.of(context);
    final TextEditingController roomNameController = TextEditingController();
    Get.defaultDialog(
      title: 'add_new_room'.tr,
      titleStyle: TextStyle(color: theme.colorScheme.onSurface),
      backgroundColor: theme.scaffoldBackgroundColor,
      content: Padding(
        padding: const EdgeInsets.all(15),
        child: TextField(
          controller: roomNameController,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            labelText: 'room_name'.tr,
            labelStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3))),
          ),
        ),
      ),
      cancel: OutlinedButton(
        onPressed: () => Get.back(), 
        child: Text('vazgec'.tr, style: TextStyle(color: theme.colorScheme.primary))
      ),
      confirm: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary),
        onPressed: () {
          if (roomNameController.text.isNotEmpty) {
            controller.addRoom({"com": "cre_oda", "txt": roomNameController.text});
            Get.back();
          }
        },
        child: Text('add'.tr, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  void _openDeleteRoomSelection(BuildContext context) {
    final theme = Theme.of(context);
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
            Text('delete_room_title'.tr, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 20),
            Obx(() => controller.rooms.isEmpty 
              ? Padding(padding: const EdgeInsets.all(20), child: Text('no_room_found'.tr, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))))
              : Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: controller.rooms.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                            title: Text('delete_all_rooms'.tr, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            onTap: () => _confirmDeleteAllRooms(context),
                          ),
                        );
                      }
                      final room = controller.rooms[index - 1];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                            child: Icon(Icons.meeting_room, color: theme.colorScheme.primary, size: 20),
                          ),
                          title: Text(room.name, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w500)),
                          trailing: Icon(Icons.delete_outline, color: Colors.redAccent.withValues(alpha: 0.7)),
                          onTap: () => _confirmDeleteRoom(context, room),
                        ),
                      );
                    },
                  ),
                ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteRoom(BuildContext context, RoomInfo room) {
    final theme = Theme.of(context);
    Get.defaultDialog(
      title: 'delete_room_title'.tr,
      middleText: 'delete_room_confirm'.trParams({'name': room.name}),
      backgroundColor: theme.scaffoldBackgroundColor,
      textConfirm: 'yes'.tr,
      textCancel: 'no'.tr,
      confirmTextColor: Colors.white,
      buttonColor: Colors.redAccent,
      onConfirm: () {
        controller.deleteRoom(room.id);
        Get.back();
        Get.back();
      },
    );
  }

  void _confirmDeleteAllRooms(BuildContext context) {
    final theme = Theme.of(context);
    Get.defaultDialog(
      title: 'delete_all_rooms'.tr,
      middleText: 'delete_all_rooms_confirm'.tr,
      backgroundColor: theme.scaffoldBackgroundColor,
      textConfirm: 'yes'.tr,
      textCancel: 'no'.tr,
      confirmTextColor: Colors.white,
      buttonColor: Colors.redAccent,
      onConfirm: () {
        controller.deleteAllRooms();
        Get.back();
        Get.back();
      },
    );
  }

  void _openDeleteSwitchSelection(BuildContext context, UserManagementService userManager) {
    final theme = Theme.of(context);

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
            Text('delete_switch'.tr, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 20),
            Flexible(
              child: Obx(() => ListView.builder(
                shrinkWrap: true,
                itemCount: userManager.activeSwitches.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                        title: Text('delete_all_switches'.tr, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        onTap: () => _confirmDeleteSwitchId(context, 99, 'all_switches'.tr),
                      ),
                    );
                  }
                  final sw = userManager.activeSwitches[index - 1];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(Icons.toggle_on_outlined, color: theme.colorScheme.primary, size: 20),
                      ),
                      title: Text(sw.name, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w500)),
                      trailing: Icon(Icons.delete_outline, color: Colors.redAccent.withValues(alpha: 0.7)),
                      onTap: () => _confirmDeleteSwitchId(context, sw.id, sw.name),
                    ),
                  );
                },
              )),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteSwitchId(BuildContext context, int id, String name) {
    final theme = Theme.of(context);
    Get.defaultDialog(
      title: 'delete_switch'.tr,
      middleText: 'delete_switch_confirm'.trParams({'name': name}),
      backgroundColor: theme.scaffoldBackgroundColor,
      textConfirm: 'yes'.tr,
      textCancel: 'no'.tr,
      confirmTextColor: Colors.white,
      buttonColor: Colors.redAccent,
      onConfirm: () {
        controller.deleteSwitch(id);
        Get.back();
        Get.back();
      },
    );
  }

  void _showAddSwitchDialog(BuildContext context) {
    final theme = Theme.of(context);
    final userManager = Get.find<UserManagementService>();
    final nameController = TextEditingController();
    
    int selectedType = 0;
    int? selectedSensorId;
    int? selectedSensorInstance;
    int? selectedRelayId;

    final List<String> types = [
      'switch_label'.tr, 
      'gas_sensor'.tr, 
      'water_sensor'.tr, 
      'thermostat'.tr, 
      'motion_sensor'.tr
    ];

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          final sensorDevices = userManager.activeDevices.where((d) => d.type == 7 && d.extension == 0x0B).toList();
          final relayDevices = userManager.activeDevices.where((d) => d.type == 7 || d.type == 2).toList();
          
          List<InsIntroScn> sensorInstances = [];
          if (selectedSensorId != null) {
            sensorInstances = userManager.activeInsIntroList.where((ins) => ins.adr == selectedSensorId).toList();
          }

          return AlertDialog(
            title: Text('add_switch'.tr),
            backgroundColor: theme.scaffoldBackgroundColor,
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(labelText: 'switch_name'.tr),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: selectedType,
                    dropdownColor: theme.scaffoldBackgroundColor,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    items: List.generate(types.length, (i) => 
                      DropdownMenuItem(value: i, child: Text(types[i]))
                    ),
                    onChanged: (val) {
                      setState(() {
                        selectedType = val ?? 0;
                      });
                    },
                    decoration: InputDecoration(labelText: 'switch_type'.tr),
                  ),
                  
                  if (selectedType != 0) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: selectedSensorId,
                      dropdownColor: theme.scaffoldBackgroundColor,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      hint: Text('select_sensor'.tr, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                      items: sensorDevices.map((d) => 
                        DropdownMenuItem(value: d.id, child: Text("${d.name} (${d.id})"))
                      ).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedSensorId = val;
                          selectedSensorInstance = null; 
                        });
                      },
                      decoration: InputDecoration(labelText: 'sensor_device'.tr),
                    ),
                    
                    if (selectedSensorId != null) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        value: selectedSensorInstance,
                        dropdownColor: theme.scaffoldBackgroundColor,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        hint: Text('select_instance'.tr, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                        items: sensorInstances.map((ins) => 
                          DropdownMenuItem(value: ins.iadr, child: Text("${'instance'.tr} ${ins.iadr}"))
                        ).toList(),
                        onChanged: (val) => setState(() => selectedSensorInstance = val),
                        decoration: InputDecoration(labelText: 'sensor_instance'.tr),
                      ),
                    ],

                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: selectedRelayId,
                      dropdownColor: theme.scaffoldBackgroundColor,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      hint: Text('select_relay'.tr, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                      items: relayDevices.map((d) => 
                        DropdownMenuItem(value: d.id, child: Text("${d.name} (${d.id})"))
                      ).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedRelayId = val;
                        });
                      },
                      decoration: InputDecoration(labelText: 'relay_device'.tr),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Get.back(), child: Text('vazgec'.tr)),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isEmpty) {
                    Get.snackbar('error'.tr, 'enter_name_error'.tr);
                    return;
                  }
                  
                  int sensorChannel = 0;
                  if (selectedSensorId != null) {
                    final sensor = userManager.activeDevices.firstWhereOrNull((d) => d.id == selectedSensorId);
                    sensorChannel = sensor?.channel ?? 0;
                  }

                  int relayChannel = 0;
                  if (selectedRelayId != null) {
                    final relay = userManager.activeDevices.firstWhereOrNull((d) => d.id == selectedRelayId);
                    relayChannel = relay?.channel ?? 0;
                  }

                  controller.addSwitch(
                    name: nameController.text,
                    type: selectedType,
                    sensorId: selectedSensorId ?? 0,
                    sensorInstance: selectedSensorInstance ?? 0,
                    relayId: selectedRelayId ?? 0,
                    relayChannel: relayChannel,
                    sensorChannel: sensorChannel,
                  );
                  Get.back();
                },
                child: Text('add'.tr),
              ),
            ],
          );
        },
      ),
    );
  }
}
