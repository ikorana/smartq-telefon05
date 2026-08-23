import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../theme/theme_service.dart';
import 'userSelectionController.dart';
import '../../main.dart'; // isTablet değişkenine erişim için eklendi

class UserProfileDialog {
  static void show(BuildContext context, {bool isEdit = false}) {
    final themeService = Get.find<ThemeService>();
    final controller = Get.find<UserSelectionController>();

    Get.dialog(
      Obx(() {
        final currentTheme = themeService.allThemes[controller.selectedThemeIndex.value];
        final bool tablet = isTablet.value;
        final bool isLightTheme = currentTheme.brightness == Brightness.light;

        // Kontrastlı metin rengi (Primary üzerine yazılacaksa)
        final Color onPrimaryColor = isLightTheme ? currentTheme.colorScheme.onSurface : Colors.white;

        // Text input alanlarını ortak bir listede topluyoruz
        final List<Widget> textFields = [
          _buildModernTextField(context: context, controller: controller.nameController, label: 'name_hint'.tr, icon: Icons.person_outline),
          const SizedBox(height: 12),
          if (!tablet) ...[
            _buildModernTextField(
              context: context, 
              controller: controller.phoneController, 
              label: 'phone_number'.tr, // 'phone_number' çevirisi eklenmeli veya direkt "Telefon Numarası" yazılabilir
              icon: Icons.phone_android_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
          ],
          _buildModernTextField(
            context: context,
            controller: controller.ipController,
            label: 'ip_label'.tr,
            icon: Icons.router_outlined,
            suffix: controller.isScanning.value
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: currentTheme.colorScheme.primary))
                : IconButton(
                    icon: const Icon(Icons.search, color: Colors.greenAccent),
                    onPressed: () => controller.scanDevices(),
                  ),
          ),
          const SizedBox(height: 12),
          _buildModernTextField(context: context, controller: controller.mqttController, label: 'mqtt_broker_label'.tr, icon: Icons.cloud_queue),
          const SizedBox(height: 12),
          _buildModernTextField(
            context: context,
            controller: controller.licController,
            label: 'license_label'.tr,
            icon: Icons.vpn_key_outlined,
            readOnly: !isEdit && controller.licenseAvatarTapCount.value < 3,
          ),
        ];

        // Seçim alanlarını (Dil, Tema, Admin) ortak bir widget olarak tanımlıyoruz
        final Widget selectorSection = Column(
          children: [
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: currentTheme.colorScheme.surface, 
                borderRadius: BorderRadius.circular(25),
                border: isLightTheme ? Border.all(color: currentTheme.colorScheme.primary.withOpacity(0.1)) : null,
              ),
              child: Row(
                children: [
                  _buildSegmentButton(context, "TR", controller.selectedLanguage.value == "tr", () {
                    controller.selectedLanguage.value = "tr";
                    Get.updateLocale(const Locale('tr'));
                  }, currentTheme),
                  _buildSegmentButton(context, "EN", controller.selectedLanguage.value == "en", () {
                    controller.selectedLanguage.value = "en";
                    Get.updateLocale(const Locale('en'));
                  }, currentTheme),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: currentTheme.colorScheme.surface, 
                borderRadius: BorderRadius.circular(25),
                border: isLightTheme ? Border.all(color: currentTheme.colorScheme.primary.withOpacity(0.1)) : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(themeService.allThemes.length, (index) {
                  final isSelected = controller.selectedThemeIndex.value == index;
                  return GestureDetector(
                    onTap: () => controller.selectedThemeIndex.value = index,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: themeService.allThemes[index].scaffoldBackgroundColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected 
                              ? currentTheme.colorScheme.primary 
                              : Colors.white24,
                          width: isSelected ? 3.0 : 1.5
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: currentTheme.colorScheme.primary.withOpacity(0.4),
                            blurRadius: 10,
                            spreadRadius: 2
                          )
                        ] : null,
                      ),
                      child: isSelected 
                        ? Icon(Icons.check, size: 18, color: currentTheme.colorScheme.primary)
                        : null,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Icon(Icons.security, color: currentTheme.colorScheme.primary),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.isAdmin.value ? 'admin_user'.tr : 'standard_user'.tr, 
                        style: TextStyle(color: currentTheme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600)
                      ),
                      if (!tablet)
                        Text('standard_user_hint'.tr, style: TextStyle(color: currentTheme.colorScheme.onSurface.withOpacity(0.6), fontSize: 10)),
                    ],
                  ),
                ),
                Switch(
                  value: controller.isAdmin.value, 
                  onChanged: controller.isAdminSwitchEnabled ? (v) => controller.isAdmin.value = v : null,
                  activeColor: currentTheme.colorScheme.primary,
                ),
              ],
            ),
          ],
        );

        return Theme(
          data: currentTheme,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: tablet ? 700 : Get.width * 0.9,
                constraints: BoxConstraints(maxHeight: Get.height * 0.9),
                decoration: BoxDecoration(
                  color: currentTheme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(30),
                  border: isLightTheme ? Border.all(color: currentTheme.colorScheme.primary.withOpacity(0.2)) : null,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Avatar ve Başlık tek satırda
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            // Lisans alanının readonly kilidini açmak için gizli bir
                            // erişim: bu avatara 3 kez dokununca kilit kalkar.
                            onTap: () => controller.licenseAvatarTapCount.value++,
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: currentTheme.colorScheme.surface,
                              child: Icon(Icons.person, size: 25, color: currentTheme.colorScheme.primary),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Text(
                            isEdit ? 'update_info'.tr : 'new_user'.tr,
                            style: TextStyle(color: currentTheme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      
                      // Cihaz tipine göre içerik yerleşimi (Tablet -> Yan Yana, Telefon -> Alt Alta)
                      if (tablet)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Column(children: textFields)),
                            const SizedBox(width: 25),
                            Expanded(child: selectorSection),
                          ],
                        )
                      else
                        Column(
                          children: [
                            ...textFields,
                            const SizedBox(height: 15),
                            selectorSection,
                          ],
                        ),

                      const SizedBox(height: 25),
                      // Alt Butonlar
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: currentTheme.colorScheme.surface,
                                foregroundColor: currentTheme.colorScheme.onSurface,
                                elevation: 0,
                                side: isLightTheme ? BorderSide(color: currentTheme.colorScheme.primary.withOpacity(0.3)) : null,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              onPressed: () => controller.cancelDialog(),
                              child: Text('cancel'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: currentTheme.colorScheme.primary,
                                foregroundColor: onPrimaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              onPressed: () => controller.saveUser(),
                              child: Text(isEdit ? 'update'.tr : 'save'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (!isEdit)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: currentTheme.colorScheme.primary.withOpacity(0.7), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'network_controller_info'.tr,
                                  style: TextStyle(
                                    color: currentTheme.colorScheme.onSurface.withOpacity(0.6),
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
      barrierDismissible: false,
    );
  }

  static Widget _buildModernTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    Widget? suffix,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: theme.brightness == Brightness.light ? Border.all(color: theme.colorScheme.primary.withOpacity(0.1)) : null,
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          icon: Icon(icon, color: theme.colorScheme.primary, size: 20),
          labelText: label,
          labelStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 11),
          suffixIcon: suffix,
        ),
      ),
    );
  }

  static Widget _buildSegmentButton(BuildContext context, String label, bool isSelected, VoidCallback onTap, ThemeData theme) {
    final bool isLightTheme = theme.brightness == Brightness.light;
    final Color textColor = isSelected 
        ? (isLightTheme ? theme.colorScheme.onSurface : Colors.white)
        : theme.colorScheme.onSurface.withOpacity(0.7);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent, 
            borderRadius: BorderRadius.circular(20)
          ),
          child: Center(
            child: Text(
              label, 
              style: TextStyle(
                color: textColor, 
                fontWeight: FontWeight.bold, 
                fontSize: 12
              )
            ),
          ),
        ),
      ),
    );
  }
}
