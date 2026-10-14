import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/player_controller.dart';
import '../state/settings_controller.dart';
import 'design.dart';

/// Colours and images that change with the theme (Settings > Themes).
///
/// A Skin can sit anywhere between light and dark ([darkness] 0..1):
/// [SkinHost] animates it, so switching theme, or turning ambient on with
/// the light theme, fades the whole app smoothly instead of snapping.
class Skin {
  const Skin({
    required this.darkness,
    required this.background,
    required this.surface,
    required this.ink,
    required this.hairline,
    required this.title,
    required this.artist,
    required this.wash,
    required this.heroShadow,
    required this.heroShadowOpacity,
    required this.icon,
    required this.blurDim,
    required this.field,
  });

  /// 0 = light, 1 = dark; in between while animating.
  final double darkness;
  bool get dark => darkness >= 0.5;

  /// Page background (library, settings, behind the open player).
  final Color background;

  /// Grouped cards (settings).
  final Color surface;

  /// Main text and icons on [background].
  final Color ink;

  /// Thin separators.
  final Color hairline;

  /// Vertical song title on the library screen.
  final Color title;

  /// Vertical artist name on the library screen.
  final Color artist;

  /// Colour the side covers fade towards (Figma: white wash).
  final Color wash;

  /// Glow/shadow behind the centred cover, and its strength (0..1).
  final Color heroShadow;
  final double heroShadowOpacity;

  /// App bar icon colour (the Figma icons are black).
  final Color icon;

  /// Extra darkening of the blurred album art, 0..1 (0.5 = half as bright).
  final double blurDim;

  /// Search field background.
  final Color field;

  static const lightSkin = Skin(
    darkness: 0,
    background: Colors.white,
    surface: Color(0xFFF3F3F1),
    ink: Palette.ink,
    hairline: Color(0x14000000),
    title: Colors.black,
    artist: Palette.muted,
    wash: Colors.white,
    heroShadow: Colors.black,
    heroShadowOpacity: 0.25,
    icon: Colors.black,
    blurDim: 0,
    field: Colors.white,
  );

  static const darkSkin = Skin(
    darkness: 1,
    background: Colors.black,
    surface: Color(0xFF141416),
    ink: Colors.white,
    hairline: Color(0x1FFFFFFF),
    title: Colors.white,
    artist: Palette.muted,
    wash: Colors.black,
    heroShadow: Colors.white,
    heroShadowOpacity: 0.22,
    icon: Colors.white,
    blurDim: 0.5,
    field: Color(0xFF1C1C1E),
  );

  static Skin lerp(Skin a, Skin b, double t) => Skin(
        darkness: lerpDouble(a.darkness, b.darkness, t)!,
        background: Color.lerp(a.background, b.background, t)!,
        surface: Color.lerp(a.surface, b.surface, t)!,
        ink: Color.lerp(a.ink, b.ink, t)!,
        hairline: Color.lerp(a.hairline, b.hairline, t)!,
        title: Color.lerp(a.title, b.title, t)!,
        artist: Color.lerp(a.artist, b.artist, t)!,
        wash: Color.lerp(a.wash, b.wash, t)!,
        heroShadow: Color.lerp(a.heroShadow, b.heroShadow, t)!,
        heroShadowOpacity:
            lerpDouble(a.heroShadowOpacity, b.heroShadowOpacity, t)!,
        icon: Color.lerp(a.icon, b.icon, t)!,
        blurDim: lerpDouble(a.blurDim, b.blurDim, t)!,
        field: Color.lerp(a.field, b.field, t)!,
      );

  static Skin forTheme(AppTheme t) => switch (t) {
        AppTheme.light => lightSkin,
        AppTheme.dark => darkSkin,
      };

  /// The current (possibly mid-animation) skin.
  static Skin of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_SkinScope>();
    if (scope != null) return scope.skin;
    // Outside a SkinHost (tests): follow the theme setting directly.
    return forTheme(
        context.select<SettingsController, AppTheme>((s) => s.theme));
  }

  SystemUiOverlayStyle get systemBars => SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            dark ? Brightness.light : Brightness.dark,
      );
}

/// How long the light/dark fade takes (theme change or ambient toggle).
const Duration skinFade = Duration(milliseconds: 900);

/// Decides whether the app should look dark and animates towards it:
/// dark when the theme setting is Dark, or while ambient mode is on.
class SkinHost extends StatefulWidget {
  const SkinHost({super.key, required this.builder});

  final Widget Function(BuildContext context, Skin skin) builder;

  @override
  State<SkinHost> createState() => _SkinHostState();
}

class _SkinHostState extends State<SkinHost>
    with SingleTickerProviderStateMixin {
  AnimationController? _t;

  @override
  void dispose() {
    _t?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userDark = context.select<SettingsController, bool>(
        (s) => s.theme == AppTheme.dark);
    final ambient = context.select<PlayerController, bool>((p) => p.ambient);
    final target = userDark || ambient ? 1.0 : 0.0;

    final t = _t ??=
        AnimationController(vsync: this, duration: skinFade, value: target);
    if (t.value != target && !(t.isAnimating && _goal == target)) {
      _goal = target;
      t.animateTo(target, curve: Curves.easeInOut);
    }

    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final skin = Skin.lerp(Skin.lightSkin, Skin.darkSkin, t.value);
        return _SkinScope(skin: skin, child: widget.builder(context, skin));
      },
    );
  }

  double? _goal;
}

class _SkinScope extends InheritedWidget {
  const _SkinScope({required this.skin, required super.child});

  final Skin skin;

  @override
  bool updateShouldNotify(_SkinScope old) => old.skin.darkness != skin.darkness;
}
