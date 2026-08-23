import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../user/userManagementService.dart';
import 'userProfileDialog.dart'; // Yeni dosyayı ekledik
import 'userSelectionController.dart';

class UserSelectionPage extends GetView<UserSelectionController> {
  const UserSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<UserSelectionController>()) {
      Get.put(UserSelectionController());
    }

    final userManager = Get.find<UserManagementService>();

    return Obx(() {
      // Dinleyiciler
      userManager.activeUser.value;
      userManager.lastActiveName.value;
      controller.highlightedName.value;
      userManager.userNames.length; 

      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          title: Text(
            'profile_management'.tr,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface, 
              fontSize: 20, 
              fontWeight: FontWeight.bold
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 15),
              child: IconButton(
                icon: Icon(Icons.add_circle, color: Theme.of(context).colorScheme.primary, size: 40),
                onPressed: () => UserProfileDialog.show(context), // Yeni sınıfı kullanıyoruz
              ),
            ),
          ],
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).scaffoldBackgroundColor,
                Theme.of(context).colorScheme.surface,
              ],
            ),
          ),
          child: controller.userNames.isEmpty 
            ? Center(child: Text('no_users_found'.tr))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                itemCount: controller.userNames.length,
                itemBuilder: (context, index) {
                  return _buildUserListItem(context, controller.userNames[index]);
                },
              ),
        ),
      );
    });
  }

  Widget _buildUserListItem(BuildContext context, String name) {
    final userManager = Get.find<UserManagementService>();
    final user = userManager.readUser(name);
    final bool isAdmin = user?.isAdmin ?? false;

    return Obx(() {
      final bool isActuallyActive = userManager.lastActiveName.value == name;
      final bool isHighlighted = controller.highlightedName.value == name;
      final colorScheme = Theme.of(context).colorScheme;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: isHighlighted 
              ? colorScheme.primary.withOpacity(0.12) 
              : colorScheme.surface.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isHighlighted ? colorScheme.primary : Colors.white10, 
            width: isHighlighted ? 2.5 : 1
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => controller.selectUser(name),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              child: Row(
                children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActuallyActive ? Colors.white : colorScheme.surface.withOpacity(0.2),
                        boxShadow: isActuallyActive ? [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.9),
                            blurRadius: 15,
                            spreadRadius: 4,
                          ),
                        ] : [],
                        border: isActuallyActive ? Border.all(color: Colors.white, width: 2) : null,
                      ),
                      child: Icon(
                        isAdmin ? Icons.admin_panel_settings : Icons.person,
                        color: isActuallyActive ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.2),
                        size: 28,
                      ),
                    ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: (isHighlighted || isActuallyActive) ? colorScheme.onSurface : colorScheme.onSurface.withOpacity(0.4), 
                            fontSize: 18, 
                            fontWeight: (isHighlighted || isActuallyActive) ? FontWeight.bold : FontWeight.w300
                          ),
                        ),
                        if (user?.phoneNumber != null && user!.phoneNumber!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              user.phoneNumber!,
                              style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.5),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        if (isActuallyActive)
                          Text(
                            'active_profile'.tr, 
                            style: TextStyle(
                              color: colorScheme.primary, 
                              fontSize: 10, 
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            )
                          ),
                      ],
                    ),
                  ),
                  Opacity(
                    opacity: (isHighlighted || isActuallyActive) ? 1.0 : 0.3,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_note, color: colorScheme.primary, size: 30),
                          onPressed: () {
                            controller.startEdit(name);
                            UserProfileDialog.show(context, isEdit: true); // Yeni sınıfı kullanıyoruz
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_sweep, color: colorScheme.error, size: 30),
                          onPressed: () => controller.deleteUser(name),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
