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

  // ---- CRT presets ----------------------------------------------------
  // Started from the Figma frames, then softened for comfortable viewing:
  // finer RGB grille (mask size 4 instead of 12), less colour fringing,
  // flicker, static and jitter, and a slower refresh bar.

  /// The whole screen behind the player.
  static CrtParams screen = CrtParams(
      scanlines: 12, scanlineSize: 6, mask: 12, maskPitch: 4,
      aberration: 16, flicker: 22, noise: 8, rollSpeed: 2, jitter: 1.5);

  /// Album art in the player bar's little screen.
  static CrtParams miniArt = CrtParams(
      curvature: 26, vignette: 9, scanlines: 30, scanlineSize: 5,
      mask: 15, maskPitch: 2, aberration: 20, flicker: 25, noise: 10,
      rollSpeed: 2, jitter: 1.5);

  /// Song title in the player bar.
  static CrtParams miniTitle = CrtParams(
      scanlines: 12, scanlineSize: 5, mask: 10, maskPitch: 3,
      aberration: 40, flicker: 25, noise: 8, rollSpeed: 2, jitter: 10);

  /// "0:50 / 5:14" in the player bar.
  static CrtParams miniTime = CrtParams(
      scanlines: 12, scanlineSize: 4.5, mask: 10, maskPitch: 3,
      aberration: 28, flicker: 15, noise: 30, rollSpeed: 2, jitter: 1.5);

  /// Album art on the TV.
  static CrtParams tvArt = CrtParams(
      curvature: 25, scanlines: 14, scanlineSize: 6, mask: 14, maskPitch: 4,
      aberration: 18, flicker: 22, noise: 8, rollSpeed: 2, jitter: 1.5);

  /// The equalizer on the TV: same glass, kept gentle so text stays sharp.
  static CrtParams tvEqualizer = CrtParams(
      curvature: 12, scanlines: 10, scanlineSize: 5, mask: 8, maskPitch: 3,
      aberration: 8, flicker: 12, noise: 4, rollSpeed: 1.5, jitter: 0);

  // ---- Carousel --------------------------------------------------------

  /// Open player, by distance from the centre (centre, next, the one
  /// after, beyond): cover size, sideways distance, 3D turn in degrees,
  /// white wash and opacity. The outer pair runs off the screen edges so
  /// it is clear the row scrolls.
  static List<double> hSize = [600, 490, 410, 360];
  static List<double> hOffset = [0, 380, 560, 700];
  static List<double> hAngle = [0, 58, 64, 68];
  static List<double> hWash = [0, 0.30, 0.50, 0.60];
  static List<double> hOpacity = [1, 1, 0.65, 0];

  /// Perspective strength of the turned covers (bigger = stronger).
  static double hPerspective = 0.0011;

  /// Where the row sits between the artist name and the TV (0 = top,
  /// 1 = bottom), measured at the centre of the covers.
  static double hCentreAt = 0.477;

  /// How long the carousel takes to settle on a song after a swipe.
  static Duration snap = const Duration(milliseconds: 320);

  // ---- Player ----------------------------------------------------------

  /// How long pulling the TV out takes.
  static Duration open = const Duration(milliseconds: 520);

  /// Mechanical click when a player or TV button goes down and comes back
  /// up (two different sounds), 0..1.
  static double buttonSoundVolume = 0.7;
}
