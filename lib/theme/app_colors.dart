import 'package:flutter/material.dart';

class AppColors extends ThemeExtension<AppColors> {
  final Color? deviceBackground;
  final Color? groupBackground;
  final Color? sceneBackground;
  final Color? sysBackground;
  final Color? error;
  final Color? labelText;

  const AppColors({
    required this.deviceBackground,
    required this.groupBackground,
    required this.sceneBackground,
    required this.sysBackground,
    required this.error,
    required this.labelText,
  });

  @override
  AppColors copyWith({
    Color? deviceBackground,
    Color? groupBackground,
    Color? sceneBackground,
    Color? sysBackground,
    Color? error,
    Color? labelText,
  }) {
    return AppColors(
      deviceBackground: deviceBackground ?? this.deviceBackground,
      groupBackground: groupBackground ?? this.groupBackground,
      sceneBackground: sceneBackground ?? this.sceneBackground,
      sysBackground: sysBackground ?? this.sysBackground,
      error: error ?? this.error,
      labelText: labelText ?? this.labelText,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      deviceBackground: Color.lerp(deviceBackground, other.deviceBackground, t),
      groupBackground: Color.lerp(groupBackground, other.groupBackground, t),
      sceneBackground: Color.lerp(sceneBackground, other.sceneBackground, t),
      sysBackground: Color.lerp(sysBackground, other.sysBackground, t),
      error: Color.lerp(error, other.error, t),
      labelText: Color.lerp(labelText, other.labelText, t),
    );
  }
}
