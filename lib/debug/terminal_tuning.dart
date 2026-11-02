import 'dart:ui' show Color;

/// One set of CRT effect settings, in the same units as the Figma "CRT"
/// effect panel (percentages 0..100 unless noted), so values can be copied
/// straight from Figma. Drawn by shaders/crt.frag.
class CrtParams {
  CrtParams({
    this.curvature = 0,
    this.scanlines = 20,
    this.scanlineSize = 8,
    this.mask = 30,
    this.maskPitch = 12,
    this.aberration = 47,
    this.flicker = 62,
    this.noise = 20,
    this.noiseSize = 1,
    this.rollSpeed = 5,
    this.jitter = 3,
    this.vignette = 0,
    this.brightness = 0,
    this.speed = 0.78,
    this.clipToCurve = true,
  });

  /// Barrel bulge of the glass.
  double curvature;

  /// Darkness of the scanlines, and their spacing in points.
  double scanlines;
  double scanlineSize;

  /// Strength of the RGB aperture-grille pattern, and its size in points
  /// (2..12).
  double mask;
  double maskPitch;

  /// Colour fringing towards the edges ("Dispersion" in Figma).
  double aberration;

  /// Brightness wobble.
  double flicker;

  /// Analog static, and its grain size in points.
  double noise;
  double noiseSize;

  /// Speed of the bright refresh bar rolling down (0 = off, up to 5).
  double rollSpeed;

  /// Sideways line jitter.
  double jitter;

  /// Darkening towards the corners.
  double vignette;

  /// -1..1, 0 = unchanged.
  double brightness;

  /// Speed of everything animated (1 = Figma's real time).
  double speed;

  /// Cut the picture to the curved glass shape.
  bool clipToCurve;
}

/// The Terminal theme. Every value here is safe to change; rebuild to see
/// it. Positions are Figma px on the 1080 x 2340 frames.
class TerminalTuning {
  TerminalTuning._();

  // ---- Colours ---------------------------------------------------------

  /// Song titles, timestamps and other glowing text.
  static Color phosphor = const Color(0xFF00FF00);

  /// Artist name.
  static Color artist = const Color(0xFF5CFF5C);

  /// Background gradient: black at the top to green (7, 123, 7) at 25%
  /// over black, reached at [gradientEnd] of the height (library: half way
  /// down; the open player: the bottom).
  static Color gradientBottom = const Color(0x40077B07);
  static double gradientEndLibrary = 0.5;
  static double gradientEndPlayer = 1.0;

  /// Soft green glow behind the big song title.
  static Color titleGlow = const Color(0xAA077B07);
  static double titleGlowBlur = 40;

  // ---- CRT presets (from the Figma frames) ----------------------------

  /// The whole screen behind the player.
  static CrtParams screen = CrtParams();

  /// Album art in the player bar's little screen.
  static CrtParams miniArt = CrtParams(
      maskPitch: 2, scanlines: 43, curvature: 26, vignette: 9,
      scanlineSize: 6.5);

  /// Song title in the player bar.
  static CrtParams miniTitle = CrtParams(jitter: 25, aberration: 100);

  /// "0:50 / 5:14" in the player bar.
  static CrtParams miniTime = CrtParams(
      flicker: 25, noise: 72, scanlineSize: 4.5, aberration: 68);

  /// Album art on the TV.
  static CrtParams tvArt = CrtParams(curvature: 25);

  // ---- Carousel --------------------------------------------------------

  /// Open player: centred cover size, and neighbour covers' size, sideways
  /// distance from the centre and 3D turn (degrees).
  static double hCentreSize = 500;
  static double hSideSize = 520;
  static double hSideOffset = 306;
  static double hSideAngle = 58;

  /// Perspective strength of the turned covers (bigger = stronger).
  static double hPerspective = 0.0011;

  /// Vertical centre of the horizontal carousel (Figma y).
  static double hCentreY = 907;

  /// White wash on the turned covers.
  static double hSideWash = 0.30;

  /// How long the carousel takes to settle on a song after a swipe.
  static Duration snap = const Duration(milliseconds: 320);

  // ---- Player ----------------------------------------------------------

  /// TV position when fully open (Figma), and how long opening takes.
  static double tvTop = 1323;
  static Duration open = const Duration(milliseconds: 520);
}
