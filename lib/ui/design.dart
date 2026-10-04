import 'package:flutter/material.dart';

/// Converts Figma px (the design frame is 1080 x 2340) to on-screen
/// logical px by scaling to the phone's width.
class Fg {
  const Fg(this.s);
  final double s;

  static Fg of(BuildContext context) =>
      Fg(MediaQuery.sizeOf(context).width / 1080);

  double call(double figmaPx) => figmaPx * s;
}

/// UI images exported from the Figma file (resized copies in assets/ui/,
/// originals in assets/ui_source/). Glass buttons are drawn with the
/// "screen" blend mode, as in the design.
class UiAssets {
  UiAssets._();
  static const play = 'assets/ui/play.png';
  static const pause = 'assets/ui/pause.png';
  static const prev = 'assets/ui/prev.png';
  static const next = 'assets/ui/next.png';
  static const minimize = 'assets/ui/minimize.png';
  static const equalizer = 'assets/ui/equalizer.png';
  static const panel = 'assets/ui/panel_bg.png';
  static const loop = 'assets/ui/loop.png';
  static const shuffle = 'assets/ui/shuffle.png';
  static const settings = 'assets/ui/settings.png';
  static const search = 'assets/ui/search.png';
  static const logo = 'assets/ui/logo.png';

  static const all = [
    play, pause, prev, next, minimize, equalizer, panel,
    loop, shuffle, settings, search, logo,
  ];

  /// Decodes every UI image up front so nothing pops in on first use.
  static Future<void> precacheAll(BuildContext context) => Future.wait(
      [for (final a in all) precacheImage(AssetImage(a), context)]);
}

/// Text styles from the Figma file. Both fonts are variable fonts, so the
/// weight is set through a font variation as well as fontWeight.
class Txt {
  Txt._();

  static TextStyle inter(double size, FontWeight weight,
          {Color color = Colors.white, double? height}) =>
      TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        fontWeight: weight,
        fontVariations: [FontVariation('wght', (weight.index + 1) * 100.0)],
        color: color,
        height: height,
      );

  /// Kumbh Sans SemiBold with the YOPQ axis at 300, as set in Figma.
  static TextStyle kumbh(double size,
          {Color color = Colors.black, double letterSpacing = 0}) =>
      TextStyle(
        fontFamily: 'KumbhSans',
        fontSize: size,
        fontWeight: FontWeight.w600,
        fontVariations: const [
          FontVariation('wght', 600),
          FontVariation('YOPQ', 300),
        ],
        color: color,
        letterSpacing: letterSpacing,
        height: 1.0,
      );
}

class Palette {
  Palette._();
  static const ink = Color(0xFF111111);
  static const muted = Color(0xFF808080);
  static const knob = Color(0xFFD9D9D9);
  // The two dots in the logo.
  static const pink = Color(0xFFE040C8);
  static const blue = Color(0xFF3A7BFF);
}
