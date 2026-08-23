import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../comminication/comminication.dart';
import '../../comminication/dataBridgeServis.dart';
import '../../comminication/discover.dart';
import '../../user/appUser.dart';
import '../../user/userManagementService.dart';
import '../../theme/theme_service.dart';


class UserSelectionController extends GetxController {
  final UserManagementService _userManager = Get.find<UserManagementService>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController(); // Telefon numarası controller eklendi
  final TextEditingController ipController = TextEditingController();
  final TextEditingController mqttController = TextEditingController();
  final TextEditingController licController = TextEditingController();

  final RxInt selectedThemeIndex = 1.obs; // Default to industrialDark
  final RxString selectedLanguage = "tr".obs;
  final RxBool isAdmin = false.obs;
  final RxBool isScanning = false.obs;

  final RxString highlightedName = "".obs;
  // "Yeni Kullanıcı" formunda lisans alanı varsayılan olarak readonly'dir —
  // popup üstündeki avatara 3 kez dokununca kilidi açılır.
  final RxInt licenseAvatarTapCount = 0.obs;
  final RxString _currentNameInput = "".obs; // UI reaktifliği için ismi Rx olarak takip ediyoruz

  String? editingUserId;
  String? discoveredDeviceId;
  String? discoveredVersion;
  int? discoveredChannels;
  int? discoveredWifi;
  int? discoveredAi;
  
  final RxString discoveredAdminStatus = "unknown".obs; 

  // Getter tipini açıkça List<String> olarak belirttim. 
  // GetX mimarisinde users listesi değiştiğinde UI bunu users.obs üzerinden dinlemeli.
  List<String> get userNames => _userManager.users.map((u) => u.name).toList();

  String get currentSsid => "_phone.currentSsid.value";

  bool get isAdminSwitchEnabled {
    final currentName = _currentNameInput.value;
    // 1. Cihazda hiç admin yoksa (default) her zaman açılabilir
    // 2. Cihazda admin varsa, sadece ismi eşleşen kişi admin yetkisini açıp kapatabilir
    return discoveredAdminStatus.value == "default" || 
           (discoveredAdminStatus.value != "unknown" && 
            discoveredAdminStatus.value != "locked" && 
            discoveredAdminStatus.value == currentName);
  }

  @override
  void onInit() {
    super.onInit();
    if (_userManager.activeUser.value != null) {
      highlightedName.value = _userManager.activeUser.value!.name;
    }
    
    // İsme göre admin yetkisini kontrol etmek için dinleyici ekliyoruz
    nameController.addListener(_handleNameChange);
  }

  void _handleNameChange() {
    final currentName = nameController.text.trim();
    _currentNameInput.value = currentName;

    // Eğer cihazda bir admin varsa ve yazılan isim onunla eşleşiyorsa otomatik admin yap
    if (discoveredAdminStatus.value != "unknown" && 
        discoveredAdminStatus.value != "default" && 
        discoveredAdminStatus.value != "locked") {
      if (currentName == discoveredAdminStatus.value) {
        isAdmin.value = true;
      } else {
        isAdmin.value = false;
      }
    }
  }

  void highlightUser(String name) {
    highlightedName.value = name;
  }

  void selectUser(String name) {
    debugPrint("--- [USER SELECTION] Kullanıcı seçiliyor: $name ---");
    _userManager.changeActiveUser(name);
    
    // Seçim sonrası UI'ın parlaması için aktif kullanıcıyı yenile
    _userManager.activeUser.refresh();
    
    // Temayı da güncelle
    if (_userManager.activeUser.value != null) {
      Get.find<ThemeService>().changeTheme(_userManager.activeUser.value!.themeIndex);
    }
    
    // Üstte açık duran ekranları (Ayarlar/Cihaz Kurulumu, Profil Yönetimi)
    // kapatıp yığının en altındaki RootGate/Dashboard'a dön. Get.offAllNamed
    // KULLANMIYORUZ — o, /root'u tamamen yeniden kurup eski DashboardController'ı
    // henüz ekrandaki DeviceCardBase widget'ları hâlâ ona referans tutarken
    // siliyordu ("DashboardController not found" crash'i). activeRooms/
    // activeDevices zaten paylaşımlı RxList olduğu için (UserManagementService),
    // Dashboard'ı yeniden kurmadan da yeni kullanıcının verisiyle otomatik
    // güncelleniyor.
    Get.until((route) => route.isFirst);
  }

  void startEdit(String name) {
    final user = _userManager.readUser(name);
    if (user != null) {
      editingUserId = user.id;
      nameController.text = user.name;
      phoneController.text = user.phoneNumber ?? "";
      ipController.text = user.deviceIp ?? "";
      mqttController.text = user.mqttIP ?? "";
      licController.text = user.license ?? "";
      selectedThemeIndex.value = user.themeIndex;
      selectedLanguage.value = user.language;
      isAdmin.value = user.isAdmin;
      
      discoveredDeviceId = user.deviceId;
      discoveredVersion = user.version;
      discoveredChannels = user.totalChannels;
      discoveredAdminStatus.value = "locked";
      discoveredWifi = user.wifi;
      discoveredAi = user.ai;
    }
  }

  Future<void> scanDevices() async {
    isScanning.value = true;
    try {
      // ipController'da girilen IP varsa unicast, yoksa broadcast tarama yapar
      String? targetIp = ipController.text.trim();
      if (targetIp.isEmpty) targetIp = null;

      List<DiscoveredDevice> devices = await NetworkScanner.discover(targetIp: targetIp);

      if (devices.isNotEmpty) {
        final device = devices.first;
        ipController.text = device.ip;
        mqttController.text = device.mqtt ?? "";
        licController.text = device.lic ?? "";
        discoveredDeviceId = device.id;
        discoveredVersion = device.version;
        discoveredChannels = device.kanal;
        discoveredAdminStatus.value = device.admin;
        discoveredWifi = device.wifi;
        discoveredAi = device.ai;

        if (device.admin != "default") {
          // Eğer cihazdaki admin ismi ile girilen isim aynı ise otomatik admin yap
          if (device.admin == nameController.text.trim()) {
            isAdmin.value = true;
          } else {
            isAdmin.value = false;
          }
        }
      } else {
        Get.snackbar("error".tr, "device_not_found_check_ip".tr);
      }
    } finally {
      isScanning.value = false;
    }
  }

  Future<void> saveUser() async {
    String name = nameController.text.trim();
    String ip = ipController.text.trim();

    if (name.isEmpty) {
      Get.snackbar("error".tr, "enter_name_error".tr);
      return;
    }

    // Aynı isimde başka bir kullanıcı var mı kontrol et
    if (_userManager.users.any((u) => u.name == name && u.id != editingUserId)) {
      Get.snackbar("error".tr, "user_already_exists".tr);
      return;
    }

    if (discoveredVersion == null) {
      Get.snackbar("error".tr, "scan_device_before_save".tr);
      return;
    }

    // Admin yetkisi kontrolü
    if (isAdmin.value && discoveredAdminStatus.value != "default" && 
        discoveredAdminStatus.value != "locked" && 
        discoveredAdminStatus.value != name) {
       Get.snackbar("error".tr, "admin_already_exists".tr);
       isAdmin.value = false;
       return;
    }

    final user = AppUser(
      name: name,
      id: editingUserId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      phoneNumber: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
      deviceIp: ip.isEmpty ? null : ip,
      mqttIP: mqttController.text.trim(),
      license: licController.text.trim(),
      themeIndex: selectedThemeIndex.value,
      language: selectedLanguage.value,
      isAdmin: isAdmin.value,
      deviceId: discoveredDeviceId,
      version: discoveredVersion,
      totalChannels: discoveredChannels,
      wifi: discoveredWifi,
      ai: discoveredAi,
    );
    
    _userManager.saveOrUpdateUser(user);

    // Ana kutuya admin bilgisini bildir
    if (user.isAdmin && user.deviceIp != null && user.deviceIp!.isNotEmpty) {
      debugPrint("SİSTEM: Ana kutuya admin bildiriliyor -> ${user.name}");
      final DataBridgeService dataBridge = Get.find<DataBridgeService>();
      dataBridge.send(
        {"com": "set_admin", "admin": user.name},
        forceUdp: true, // IP adresi bilindiği için doğrudan UDP ile gönderiyoruz
        receiver: MessageOwner(
          transmission: TransmissionType.udp, 
          ip: user.deviceIp!,
          port: 53250,
        ),
      );
    }

    // EĞER GÜNCELLENEN KULLANICI AKTİF KULLANICI İSE TEMAYI ANINDA DEĞİŞTİR
    if (_userManager.activeUser.value?.id == user.id) {
       Get.find<ThemeService>().changeTheme(user.themeIndex);
    }

    _clearFields();
    if (Get.isDialogOpen == true) {
      Get.back();
    } else if (Get.isBottomSheetOpen == true) {
      Get.back();
    }
  }

  void deleteUser(String name) {
    final user = _userManager.readUser(name);
    if (user != null && user.isAdmin) {
      Get.snackbar("error".tr, "cannot_delete_admin".tr);
      return; 
    }

    Get.defaultDialog(
      title: 'delete_confirm_title'.tr,
      middleText: 'delete_confirm_msg'.trParams({'name': name}),
      textConfirm: 'yes'.tr,
      textCancel: 'no'.tr,
      onConfirm: () {
        if (user != null) {
          _userManager.deleteUser(user.id);
        }
        if (Get.isDialogOpen!) Get.back();
      },
    );
  }

  void _clearFields() {
    nameController.clear();
    phoneController.clear();
    ipController.clear();
    mqttController.clear();
    licController.clear();
    selectedThemeIndex.value = 1;
    selectedLanguage.value = "tr";
    isAdmin.value = false;
    editingUserId = null;
    discoveredDeviceId = null;
    discoveredVersion = null;
    discoveredChannels = null;
    discoveredAdminStatus.value = "unknown";
    _currentNameInput.value = "";
    discoveredWifi = null;
    discoveredAi = null;
    licenseAvatarTapCount.value = 0;
  }

  void cancelDialog() {
    _clearFields();
    Get.back();
  }

  @override
  void onClose() {
    nameController.removeListener(_handleNameChange);
    nameController.dispose();
    phoneController.dispose();
    ipController.dispose();
    mqttController.dispose();
    licController.dispose();
    super.onClose();
  }
}
