import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app_colors.dart';

class ThemeService extends GetxService {
  final RxInt _currentThemeIndex = 0.obs;
  int get currentThemeIndex => _currentThemeIndex.value;

  // --- 1. MAT INDUSTRIAL LIGHT (Pastel Mavi/Gri) ---
  late final ThemeData industrialLight = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF1F5F9), // Çok açık gri
    primaryColor: const Color(0xFF64748B), // Pastel Slate
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF475569),
      surface: Colors.white,
      onSurface: Color(0xFF1E293B),
      secondary: Color(0xFF94A3B8),
    ),
    extensions: [
      const AppColors(
        deviceBackground: Color(0xFFF8FAFC),
        groupBackground: Color(0xFFF1F5F9),
        sceneBackground: Colors.white,
        sysBackground: Color(0xFFE2E8F0),
        error: Color(0xFFEF4444),
        labelText: Colors.black
      ),
    ],
  );

  // --- 2. INDUSTRIAL NAVY (Pastel Lacivert) ---
  late final ThemeData industrialDark = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF1E293B), // Slate Dark
    primaryColor: const Color(0xFF38BDF8), // Pastel Sky Blue
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF38BDF8),
      surface: Color(0xFF334155),
      onSurface: Color(0xFFF1F5F9),
      secondary: Color(0xFF94A3B8),
    ),
    extensions: [
      const AppColors(
        deviceBackground: Color(0xFF334155),
        groupBackground: Color(0xFF475569),
        sceneBackground: Color(0xFF1E293B),
        sysBackground: Color(0xFF0F172A),
        error: Color(0xFFF87171),
        labelText: Colors.white
      ),
    ],
  );

  // --- 3. DEEP EMERALD (Koyu Yeşil Zemin & Gri Kutular) ---
  late final ThemeData forestTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF022C22), // Çok koyu zümrüt
    primaryColor: const Color(0xFF10B981), // Zümrüt Yeşili
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF10B981),
      surface: Color(0xFF1F2937), // Koyu Gri (Slate 800)
      onSurface: Color(0xFFD1FAE5),
      secondary: Color(0xFF059669),
    ),
    extensions: [
      const AppColors(
        deviceBackground: Color(0xFF374151), // Gri (Slate 700)
        groupBackground: Color(0xFF1F2937), // Koyu Gri
        sceneBackground: Color(0xFF111827), // Çok Koyu Gri (Slate 900)
        sysBackground: Color(0xFF022C22),
        error: Color(0xFFF87171),
        labelText: Colors.white,
      ),
    ],
  );

  // --- 4. DUSTY ROSE / LAVENDER (Pastel Mor/Pembe) ---
  late final ThemeData purpleTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF5F3FF), // Çok açık lavanta
    primaryColor: const Color(0xFFAD99B5), // Pastel Dusty Rose
    colorScheme: const ColorScheme.light(
      primary: Color(0xFFAD99B5),
      surface: Colors.white,
      onSurface: Color(0xFF4A374A),
      secondary: Color(0xFFD1C4E9),
    ),
    extensions: [
      const AppColors(
        deviceBackground: Color(0xFFFAF9FF),
        groupBackground: Color(0xFFF5F3FF),
        sceneBackground: Colors.white,
        sysBackground: Color(0xFFEDE9FE),
        error: Color(0xFFFB7185),
        labelText: Colors.black,
      ),
    ],
  );

  // --- 5. SAND / TERRACOTTA (Pastel Toprak) ---
  late final ThemeData carbonTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFFAF7F2), // Çok açık kum
    primaryColor: const Color(0xFFC2A69A), // Pastel Terracotta
    colorScheme: const ColorScheme.light(
      primary: Color(0xFFC2A69A),
      surface: Colors.white,
      onSurface: Color(0xFF453C38),
      secondary: Color(0xFFE5D3C5),
    ),
    extensions: [
      const AppColors(
        deviceBackground: Color(0xFFFDFCFB),
        groupBackground: Color(0xFFFAF7F2),
        sceneBackground: Colors.white,
        sysBackground: Color(0xFFF0EADF),
        error: Color(0xFFF43F5E),
        labelText: Colors.black,
      ),
    ],
  );

  // --- 6. MIDNIGHT (Tam Siyah Zemin) ---
  late final ThemeData midnightTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    primaryColor: const Color(0xFF60A5FA), // Pastel Mavi
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF60A5FA),
      surface: Color(0xFF121212),
      onSurface: Colors.white,
      secondary: Color(0xFF3B82F6),
    ),
    extensions: [
      const AppColors(
        deviceBackground: Color(0xFF1E1E1E),
        groupBackground: Color(0xFF121212),
        sceneBackground: Colors.black,
        sysBackground: Color(0xFF0A0A0A),
        error: Color(0xFFEF4444),
        labelText: Colors.white,
      ),
    ],
  );

  List<ThemeData> get allThemes => [
        industrialLight,
        industrialDark,
        forestTheme,
        purpleTheme,
        carbonTheme,
        midnightTheme,
      ];

  void changeTheme(int index) {
    if (index < 0 || index >= allThemes.length) return;
    _currentThemeIndex.value = index;
    Get.changeTheme(allThemes[index]);
    
    Future.delayed(const Duration(milliseconds: 100), () {
      Get.forceAppUpdate();
    });
  }

  @override
  void onInit() {
    super.onInit();
    // Başlangıçta Industrial Dark (indeks 1) seçili gelsin
    changeTheme(1);
  }
}
