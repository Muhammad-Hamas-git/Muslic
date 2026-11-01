import 'dart:ui' show Color;

/// The XMB theme's animated background (lib/widgets/xmb_background.dart).
/// Every value here is safe to change; rebuild to see it.
///
/// The wave is a 3D sheet drawn as a mesh, lit like the PS3's: it is clear
/// where it faces you and bright where it folds and turns edge-on. It runs
/// down the left side of the screen like the Figma frames.
class XmbTuning {
  XmbTuning._();

  // ---- Background gradient (top-left to bottom-right) ------------------

  /// Light mode: deep navy to bright blue.
  static List<Color> lightGradient = [
    Color(0xFF06316E),
    Color(0xFF158BC6),
    Color(0xFF004EF7),
  ];

  /// Dark mode: black to very dark grey.
  static List<Color> darkGradient = [
    Color(0xFF000000),
    Color(0xFF09090A),
    Color(0xFF1E1E21),
  ];

  /// Where the middle colour sits along the gradient (0..1).
  static double gradientMid = 0.55;

  // ---- Wave placement (fractions of screen width) ----------------------

  /// Centre of the wave at mid height, and how far it leans right going
  /// down (top centre = centre - lean, bottom centre = centre + lean).
  static double centre = 0.24;
  static double lean = 0.13;

  /// Width of the sheet (half width), and how much wider it gets lower down.
  static double spread = 0.101;
  static double spreadLean = 0.05;

  /// The three rolling waves that bend the sheet: amplitude (fraction of
  /// width), frequency along the screen, twist across the sheet, speed.
  /// Twist is what makes it fold over and catch the light.
  static List<WaveTerm> waves = [
    WaveTerm(amp: 0.070, along: 1.5, twist: 2.4, speed: 0.35, phase: 0.0),
    WaveTerm(amp: 0.050, along: 2.9, twist: -3.2, speed: -0.50, phase: 1.3),
    WaveTerm(amp: 0.025, along: 5.5, twist: 4.0, speed: 0.80, phase: 2.2),
  ];

  /// Overall flow speed of the waves (1 = as above).
  static double flowSpeed = 1.0;

  // ---- Lighting --------------------------------------------------------

  /// Sheet opacity in light and dark mode.
  static double opacityLight = 1.0;
  static double opacityDark = 0.85;

  /// Faint fill where the sheet faces you (0..1).
  static double baseAlpha = 0.10;

  /// Brightness of edge-on parts and how tightly it hugs the folds
  /// (higher power = thinner, sharper bright lines).
  static double fresnel = 1.0;
  static double fresnelPower = 2.5;

  /// Extra brightness on the back side of a fold.
  static double backBoost = 0.14;

  /// Depth of the sheet relative to screen width. Smaller = more of the
  /// sheet looks edge-on (brighter overall).
  static double depth = 0.22;

  /// Mesh detail: rows down the screen, columns across the sheet.
  /// 96 x 22 is smooth on a 1080p phone and costs well under 1 ms.
  static const int rows = 96;
  static const int columns = 22;

  // ---- Scroll ------------------------------------------------------------

  /// Scrolling adds "energy": the waves speed up and grow, then calm
  /// down over [energyDecay]. The wave does not react to touches.
  static double energyPerPx = 0.0016;
  static double energyPerSong = 0.10;
  static double energyMax = 1.6;
  static double energySpeedBoost = 2.2;
  static double energyAmpBoost = 0.45;
  static Duration energyDecay = Duration(milliseconds: 1200);

  // ---- Player ----------------------------------------------------------

  /// Opacity of the blurred album art behind the mini player and the open
  /// player in XMB (the controls and text stay fully solid).
  static double playerBackgroundOpacity = 0.75;

  // ---- Particles -------------------------------------------------------

  /// Number of sparkles.
  static const int particles = 110;

  /// Share of sparkles that gather around the wave (the rest float
  /// anywhere).
  static double nearWave = 0.7;

  /// Sparkle radius range in screen points; above 1 makes small ones more
  /// common.
  static double minSize = 0.39;
  static double maxSize = 1.66;
  static double sizeBias = 3.0;

  /// Brightness in light and dark mode.
  static double particleOpacityLight = 1.0;
  static double particleOpacityDark = 1.0;

  /// Drift speed upwards along the wave, points per second.
  static double drift = 16;

  /// Each sparkle fades in and out over a random time in this range.
  static Duration minTwinkle = Duration(milliseconds: 2500);
  static Duration maxTwinkle = Duration(milliseconds: 7000);

  /// A finger pushes sparkles away within this radius (fraction of width),
  /// with this strength (points per second squared at the centre).
  static double repelRadius = 0.28;
  static double repelForce = 2600;

  /// Scrolling blows sparkles along with the finger: share of the finger's
  /// speed passed on.
  static double wind = 0.35;

  /// Scrolling the library moves the background along with it, slower
  /// than the covers for depth: the wave moves at [waveScroll] of the
  /// scroll speed, sparkles between [particleScrollMin] (smallest, far
  /// away) and [particleScrollMax] (biggest, closest).
  static double waveScroll = 0.18;
  static double particleScrollMin = 0.30;
  static double particleScrollMax = 0.75;

  /// How quickly pushed sparkles slow back down to their drift (per second).
  static double particleDamping = 2.2;
}

class WaveTerm {
  WaveTerm({
    required this.amp,
    required this.along,
    required this.twist,
    required this.speed,
    required this.phase,
  });
  double amp, along, twist, speed, phase;
}
