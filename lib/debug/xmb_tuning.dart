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
  static const List<Color> lightGradient = [
    Color(0xFF06126E),
    Color(0xFF1537C6),
    Color(0xFF2F6EF7),
  ];

  /// Dark mode: black to very dark grey.
  static const List<Color> darkGradient = [
    Color(0xFF000000),
    Color(0xFF09090A),
    Color(0xFF1E1E21),
  ];

  /// Where the middle colour sits along the gradient (0..1).
  static const double gradientMid = 0.55;

  // ---- Wave placement (fractions of screen width) ----------------------

  /// Centre of the wave at mid height, and how far it leans right going
  /// down (top centre = centre - lean, bottom centre = centre + lean).
  static const double centre = 0.24;
  static const double lean = 0.13;

  /// Width of the sheet (half width), and how much wider it gets lower down.
  static const double spread = 0.15;
  static const double spreadLean = 0.05;

  /// The three rolling waves that bend the sheet: amplitude (fraction of
  /// width), frequency along the screen, twist across the sheet, speed.
  /// Twist is what makes it fold over and catch the light.
  static const List<WaveTerm> waves = [
    WaveTerm(amp: 0.070, along: 1.5, twist: 2.4, speed: 0.35, phase: 0.0),
    WaveTerm(amp: 0.050, along: 2.9, twist: -3.2, speed: -0.50, phase: 1.3),
    WaveTerm(amp: 0.025, along: 5.5, twist: 4.0, speed: 0.80, phase: 2.2),
  ];

  /// Overall flow speed of the waves (1 = as above).
  static const double flowSpeed = 1.0;

  // ---- Lighting --------------------------------------------------------

  /// Sheet opacity in light and dark mode.
  static const double opacityLight = 0.80;
  static const double opacityDark = 0.62;

  /// Faint fill where the sheet faces you (0..1).
  static const double baseAlpha = 0.07;

  /// Brightness of edge-on parts and how tightly it hugs the folds
  /// (higher power = thinner, sharper bright lines).
  static const double fresnel = 0.80;
  static const double fresnelPower = 3.0;

  /// Extra brightness on the back side of a fold.
  static const double backBoost = 0.10;

  /// Depth of the sheet relative to screen width. Smaller = more of the
  /// sheet looks edge-on (brighter overall).
  static const double depth = 0.22;

  /// Mesh detail: rows down the screen, columns across the sheet.
  /// 96 x 22 is smooth on a 1080p phone and costs well under 1 ms.
  static const int rows = 96;
  static const int columns = 22;

  // ---- Touch and scroll ------------------------------------------------

  /// How hard a touch pushes the wave away, as a fraction of width.
  static const double touchPush = 0.07;

  /// Height of the pushed part, as a fraction of screen height.
  static const double touchReach = 0.16;

  /// How long a push takes to settle, and how fast it wobbles back.
  static const Duration touchSettle = Duration(milliseconds: 1600);
  static const double touchWobble = 5.5; // radians per second

  /// Dragging or scrolling adds "energy": the waves speed up and grow,
  /// then calm down over [energyDecay].
  static const double energyPerPx = 0.0016;
  static const double energyPerSong = 0.10;
  static const double energyMax = 1.6;
  static const double energySpeedBoost = 2.2;
  static const double energyAmpBoost = 0.45;
  static const Duration energyDecay = Duration(milliseconds: 1200);

  // ---- Particles -------------------------------------------------------

  /// Number of sparkles.
  static const int particles = 110;

  /// Share of sparkles that gather around the wave (the rest float
  /// anywhere).
  static const double nearWave = 0.7;

  /// Sparkle radius range in screen points; above 1 makes small ones more
  /// common.
  static const double minSize = 1.0;
  static const double maxSize = 3.2;
  static const double sizeBias = 3.0;

  /// Brightness in light and dark mode.
  static const double particleOpacityLight = 0.85;
  static const double particleOpacityDark = 0.75;

  /// Drift speed upwards along the wave, points per second.
  static const double drift = 16;

  /// Each sparkle fades in and out over a random time in this range.
  static const Duration minTwinkle = Duration(milliseconds: 2500);
  static const Duration maxTwinkle = Duration(milliseconds: 7000);

  /// A finger pushes sparkles away within this radius (fraction of width),
  /// with this strength (points per second squared at the centre).
  static const double repelRadius = 0.28;
  static const double repelForce = 2600;

  /// Scrolling blows sparkles along with the finger: share of the finger's
  /// speed passed on.
  static const double wind = 0.35;

  /// How quickly pushed sparkles slow back down to their drift (per second).
  static const double particleDamping = 2.2;
}

class WaveTerm {
  const WaveTerm({
    required this.amp,
    required this.along,
    required this.twist,
    required this.speed,
    required this.phase,
  });
  final double amp, along, twist, speed, phase;
}
