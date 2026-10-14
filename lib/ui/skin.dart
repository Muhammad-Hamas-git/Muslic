import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/settings_controller.dart';
import 'design.dart';

/// Colours and images that change with the theme (Settings > Themes).
/// Each value is a plain field, so tweaking a theme is a one-line edit.
class Skin {
  const Skin({
    required this.dark,
    required this.background,
    required this.title,
    required this.artist,
    required this.wash,
    required this.heroShadow,
    required this.heroShadowOpacity,
    required this.icon,
    required this.logo,
    required this.blurDim,
    required this.field,
  });

  final bool dark;

  /// Page background (library, settings, behind the open player).
  final Color background;

  /// Vertical song title on the library screen.
  final Color title;

  /// Vertical artist name on the library screen.
  final Color artist;

  /// Colour the side covers fade towards (Figma: white wash).
  final Color wash;

  /// Glow/shadow behind the centred cover, and its strength (0..1).
  final Color heroShadow;
  final double heroShadowOpacity;

  /// App bar icon colour (null = the icon's own colour from Figma).
  final Color? icon;

  /// App bar logo image.
  final String logo;

  /// Extra darkening of the blurred album art, 0..1 (0.5 = half as bright).
  final double blurDim;

  /// Search field background.
  final Color field;

  static const lightSkin = Skin(
    dark: false,
    background: Colors.white,
    title: Colors.black,
    artist: Palette.muted,
    wash: Colors.white,
    heroShadow: Colors.black,
    heroShadowOpacity: 0.25,
    icon: null,
    logo: UiAssets.logo,
    blurDim: 0,
    field: Colors.white,
  );

  static const darkSkin = Skin(
    dark: true,
    background: Colors.black,
    title: Colors.white,
    artist: Palette.muted,
    wash: Colors.black,
    heroShadow: Colors.white,
    heroShadowOpacity: 0.22,
    icon: Colors.white,
    logo: UiAssets.logoDark,
    blurDim: 0.5,
    field: Color(0xFF1C1C1E),
  );

  static Skin forTheme(AppTheme t) => switch (t) {
        AppTheme.light => lightSkin,
        AppTheme.dark => darkSkin,
      };

  static Skin of(BuildContext context) =>
      forTheme(context.select<SettingsController, AppTheme>((s) => s.theme));

  SystemUiOverlayStyle get systemBars => SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            dark ? Brightness.light : Brightness.dark,
      );
}
