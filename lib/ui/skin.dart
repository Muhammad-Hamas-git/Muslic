import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../debug/terminal_tuning.dart';
import '../state/player_controller.dart';
import '../state/settings_controller.dart';
import 'design.dart';

/// Colours and images that change with the theme (Settings > Appearance).
///
/// There are four skins: Classic light/dark and Wave light/dark. A Skin can
/// sit anywhere between them: [SkinHost] animates it, so switching theme
/// or style, or turning ambient on with the light theme, fades the whole
/// app smoothly instead of snapping.
///
/// Wave always uses the dark skin's element colours (white logo, titles,
/// icons, text); its light/dark mode only changes the background gradient
/// ([night]) and the player card ([blurDim]).
class Skin {
  const Skin({
    required this.darkness,
    required this.night,
    required this.xmb,
    required this.edgeFade,
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

  /// Element colours: 0 = light (black logo/text), 1 = dark (white).
  /// In between while animating.
  final double darkness;
  bool get dark => darkness >= 0.5;

  /// The chosen light/dark mode itself, 0..1. Same as [darkness] in
  /// Classic; in Wave it picks the blue (0) or black (1) background.
  final double night;

  /// How much of the Wave background shows, 0 (Classic) to 1 (Wave).
  final double xmb;

  /// Strength of the white/black fades at the top and bottom of the
  /// library (Classic only; Wave lets the background show through).
  final double edgeFade;

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
    night: 0,
    xmb: 0,
    edgeFade: 1,
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
    night: 1,
    xmb: 0,
    edgeFade: 1,
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

  /// Wave, light mode: blue background, dark-mode element colours, light
  /// player card. Side covers keep the white wash (Figma "Library Screen
  /// (Wave)").
  static const xmbLightSkin = Skin(
    darkness: 1,
    night: 0,
    xmb: 1,
    edgeFade: 0,
    background: Color(0xFF1435C2),
    surface: Color(0x30000000),
    ink: Colors.white,
    hairline: Color(0x24FFFFFF),
    title: Colors.white,
    artist: Colors.white,
    wash: Colors.white,
    heroShadow: Colors.white,
    heroShadowOpacity: 0.25,
    icon: Colors.white,
    blurDim: 0,
    field: Color(0xFF1C1C1E),
  );

  /// Wave, dark mode: black-to-dark-grey background, dark player card.
  static const xmbDarkSkin = Skin(
    darkness: 1,
    night: 1,
    xmb: 1,
    edgeFade: 0,
    background: Colors.black,
    surface: Color(0x1AFFFFFF),
    ink: Colors.white,
    hairline: Color(0x1FFFFFFF),
    title: Colors.white,
    artist: Colors.white,
    wash: Colors.white,
    heroShadow: Colors.white,
    heroShadowOpacity: 0.25,
    icon: Colors.white,
    blurDim: 0.5,
    field: Color(0xFF1C1C1E),
  );

  static Skin lerp(Skin a, Skin b, double t) => Skin(
        darkness: lerpDouble(a.darkness, b.darkness, t)!,
        night: lerpDouble(a.night, b.night, t)!,
        xmb: lerpDouble(a.xmb, b.xmb, t)!,
        edgeFade: lerpDouble(a.edgeFade, b.edgeFade, t)!,
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

  /// Terminal: green phosphor on black, for every screen that is not the
  /// Terminal library itself (settings, dialogs).
  static const terminalSkin = Skin(
    darkness: 1,
    night: 1,
    xmb: 0,
    edgeFade: 0,
    background: Colors.black,
    surface: Color(0x1A00FF00),
    ink: Color(0xFF39FF39),
    hairline: Color(0x3300FF00),
    title: Color(0xFF00FF00),
    artist: Color(0xFF5CFF5C),
    wash: Colors.white,
    heroShadow: Colors.white,
    heroShadowOpacity: 0.25,
    icon: Color(0xFF00FF00),
    blurDim: 0.5,
    field: Color(0xFF0A1A0A),
  );

  /// Terminal in Amber: orange phosphor on black.
  static const terminalAmberSkin = Skin(
    darkness: 1,
    night: 1,
    xmb: 0,
    edgeFade: 0,
    background: Colors.black,
    surface: Color(0x1AFFA733),
    ink: Color(0xFFFFB347),
    hairline: Color(0x33FFA733),
    title: Color(0xFFFFA733),
    artist: Color(0xFFFFD9A0),
    wash: Colors.white,
    heroShadow: Colors.white,
    heroShadowOpacity: 0.25,
    icon: Color(0xFFFFA733),
    blurDim: 0.5,
    field: Color(0xFF1A120A),
  );

  static Skin forTheme(AppTheme t,
          [AppStyle style = AppStyle.classic,
          TerminalTint tint = TerminalTint.phosphor]) =>
      switch ((style, t)) {
        (AppStyle.terminal, _) =>
          tint == TerminalTint.amber ? terminalAmberSkin : terminalSkin,
        (AppStyle.classic, AppTheme.light) => lightSkin,
        (AppStyle.classic, AppTheme.dark) => darkSkin,
        (AppStyle.xmb, AppTheme.light) => xmbLightSkin,
        (AppStyle.xmb, AppTheme.dark) => xmbDarkSkin,
      };

  /// Blend of the skins: [dark] picks light/dark, [xmb] Wave, [terminal]
  /// Terminal.
  static Skin mix(double dark, double xmb,
          [double terminal = 0, double amber = 0]) =>
      lerp(
          lerp(lerp(lightSkin, darkSkin, dark),
              lerp(xmbLightSkin, xmbDarkSkin, dark), xmb),
          lerp(terminalSkin, terminalAmberSkin, amber),
          terminal);

  /// The current (possibly mid-animation) skin.
  static Skin of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_SkinScope>();
    if (scope != null) return scope.skin;
    // Outside a SkinHost (tests): follow the theme setting directly.
    final (theme, style, tint) = context.select<SettingsController,
        (AppTheme, AppStyle, TerminalTint)>(
            (s) => (s.theme, s.style, s.terminalTint));
    return forTheme(theme, style, tint);
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

/// How long the light/dark fade takes (theme change or ambient toggle),
/// and the Classic/Wave cross-fade.
const Duration skinFade = Duration(milliseconds: 900);

/// Decides how the app should look and animates towards it: dark when the
/// theme setting is Dark or while ambient mode is on; Wave when the style
/// setting is Wave.
class SkinHost extends StatefulWidget {
  const SkinHost({super.key, required this.builder});

  final Widget Function(BuildContext context, Skin skin) builder;

  @override
  State<SkinHost> createState() => _SkinHostState();
}

class _SkinHostState extends State<SkinHost> with TickerProviderStateMixin {
  AnimationController? _dark;
  AnimationController? _xmb;
  AnimationController? _term;
  double? _darkGoal;
  double? _xmbGoal;
  double? _termGoal;

  @override
  void dispose() {
    _dark?.dispose();
    _xmb?.dispose();
    _term?.dispose();
    super.dispose();
  }

  void _towards(AnimationController c, double target, double? goal,
      void Function(double) setGoal) {
    if (c.value != target && !(c.isAnimating && goal == target)) {
      setGoal(target);
      c.animateTo(target, curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (userDark, style, tint) = context.select<SettingsController,
        (bool, AppStyle, TerminalTint)>(
            (s) => (s.theme == AppTheme.dark, s.style, s.terminalTint));
    final amber = tint == TerminalTint.amber;
    // Terminal widgets read their colours from here.
    TerminalTuning.amber = amber;
    final xmbStyle = style == AppStyle.xmb;
    final ambient = context.select<PlayerController, bool>((p) => p.ambient);
    final darkTarget = userDark || ambient ? 1.0 : 0.0;
    final xmbTarget = xmbStyle ? 1.0 : 0.0;

    final d = _dark ??= AnimationController(
        vsync: this, duration: skinFade, value: darkTarget);
    final x = _xmb ??=
        AnimationController(vsync: this, duration: skinFade, value: xmbTarget);
    _towards(d, darkTarget, _darkGoal, (g) => _darkGoal = g);
    _towards(x, xmbTarget, _xmbGoal, (g) => _xmbGoal = g);
    final termTarget = style == AppStyle.terminal ? 1.0 : 0.0;
    final tm = _term ??= AnimationController(
        vsync: this, duration: skinFade, value: termTarget);
    _towards(tm, termTarget, _termGoal, (g) => _termGoal = g);

    return AnimatedBuilder(
      animation: Listenable.merge([d, x, tm]),
      builder: (context, _) {
        final skin = Skin.mix(d.value, x.value, tm.value, amber ? 1 : 0);
        return _SkinScope(skin: skin, child: widget.builder(context, skin));
      },
    );
  }
}

class _SkinScope extends InheritedWidget {
  const _SkinScope({required this.skin, required super.child});

  final Skin skin;

  @override
  bool updateShouldNotify(_SkinScope old) =>
      old.skin.darkness != skin.darkness ||
      old.skin.night != skin.night ||
      old.skin.xmb != skin.xmb ||
      old.skin.ink != skin.ink;
}
