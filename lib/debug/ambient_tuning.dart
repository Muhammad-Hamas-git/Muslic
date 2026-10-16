/// "Ambient" mode: one tap turns the playing song into a slowed + reverb
/// version. Every value here is safe to change; rebuild to hear it.
///
/// Signal flow (Android): decoded song -> speed/pitch -> reverb + echo ->
/// equalizer -> boost -> speaker. The reverb runs after slowing, so its tail
/// keeps natural timing on the slowed track.
class AmbientTuning {
  AmbientTuning._();

  // ---- Speed and pitch -------------------------------------------------

  /// Playback speed while ambient is on (1.0 = normal).
  static const double speed = 0.8;

  /// Pitch while ambient is on (1.0 = normal). Same as [speed] gives the
  /// classic "slowed" sound of playing a record too slow.
  static const double pitch = 0.8;

  /// How long the slow-down glides when ambient turns on or off.
  /// 0 = instant. Around 1500 ms sounds like a record winding down.
  static const Duration ramp = Duration(milliseconds: 1400);

  /// Number of steps in that glide (more = smoother, more work).
  static const int rampSteps = 24;

  // ---- Reverb (Freeverb) ----------------------------------------------

  /// Level of the dry (original) signal. Below 1 makes room for the reverb
  /// so ambient is not louder than the original (these defaults measure
  /// 0 dB change with nothing reaching the limiter) and pushes the song
  /// "back into the room".
  static const double dry = 0.80;

  /// Reverb level, 0..1. Capped at the Reverb toggle's "On" level (0.16,
  /// i.e. 50%): above that it starts to distort. If you raise it, lower
  /// [dry] to keep the loudness the same.
  static const double reverbWet = 0.16;

  /// Room size, 0..1. Controls how long the tail lasts.
  /// 0.5 = small room, 0.85 = hall, 0.95 = cathedral.
  static const double roomSize = 0.88;

  /// High-frequency damping, 0..1. Higher = darker, softer tail.
  static const double damping = 0.45;

  /// Stereo width of the reverb, 0..1.
  static const double width = 1.0;

  /// Gap before the reverb starts, in ms (0..250). 20 to 60 keeps vocals
  /// clear of the reverb.
  static const double preDelayMs = 35;

  // ---- Echo (delay) ---------------------------------------------------

  /// Echo level, 0..1. Keep it subtle; reverb does most of the work.
  /// Stay at or below the Echo toggle's "On" level (0.225, i.e. 50%).
  static const double echoWet = 0.12;

  /// Time between repeats, in ms (1..2000). 300 to 450 suits slowed songs.
  static const double echoMs = 420;

  /// How much each repeat feeds the next, 0..0.95. Higher = more repeats.
  static const double echoFeedback = 0.32;

  /// Low-pass on the repeats, in Hz. Lower = darker, more "tape" echoes.
  static const double echoToneHz = 2800;

  /// How long the effects fade in and out, in ms.
  static const double fxFadeMs = 900;
}

/// The Reverb and Echo toggles in the equalizer panel. "On" plays them at
/// [onLevel] of the full values below (0.5 = 50%; higher distorts).
class FxTuning {
  FxTuning._();

  static const double onLevel = 0.5;

  // Reverb at full (100%). On = onLevel x this.
  static const double reverbWetMax = 0.32;
  static const double roomSize = 0.82;
  static const double damping = 0.4;
  static const double width = 1.0;
  static const double preDelayMs = 25;

  // Echo at full (100%). On = onLevel x this.
  static const double echoWetMax = 0.45;
  static const double echoMs = 360;
  static const double echoFeedback = 0.38;
  static const double echoToneHz = 3500;

  /// The original signal is lowered as reverb/echo go up, so the sliders
  /// add space without making songs louder (measured within ±2 dB).
  /// dry = 1 - dryDuckReverb * reverb - dryDuckEcho * echo.
  static const double dryDuckReverb = 0.30;
  static const double dryDuckEcho = 0.10;

  /// Fade time when a toggle changes, in ms.
  static const double fadeMs = 150;
}

/// How the album art turns into a spinning CD while ambient is on.
class CdTuning {
  CdTuning._();

  /// How long the square cover takes to become a disc (and back).
  static const Duration morph = Duration(milliseconds: 900);

  /// Time for one full turn. Higher = slower. 12 to 20 s reads as "calm".
  static const Duration spinPeriod = Duration(seconds: 16);

  /// How long the disc takes to speed up or slow down (play, pause,
  /// ambient on). Also how long it takes to turn back upright when ambient
  /// turns off.
  static const Duration spinRamp = Duration(milliseconds: 1200);

  /// Spin only while music plays (true), or always while ambient is on.
  static const bool spinOnlyWhilePlaying = true;

  /// Size of the CD case relative to the normal album art square.
  static const double caseScale = 1.04;

  /// Disc diameter as a fraction of the case's side.
  static const double discSize = 0.84;

  /// Centre of the disc inside the case (0..1 on each axis). The tray in
  /// the case image is very slightly up and left of the image centre.
  static const double discCentreX = 0.497;
  static const double discCentreY = 0.497;

  /// Diameter of the hole as a fraction of the disc. A real CD is 0.125.
  static const double holeSize = 0.11;

  /// Strength of the case overlay (drawn with the screen blend), 0..1.
  static const double caseOpacity = 1.0;
}

/// The twinkling stars behind everything while ambient is on.
class StarTuning {
  StarTuning._();

  /// Number of stars on screen. 50 to 90 stays sparse.
  static const int count = 70;

  /// Smallest and largest star radius, in screen points.
  static const double minRadius = 0.6;
  static const double maxRadius = 2.1;

  /// Above 1 makes small stars more common than big ones.
  static const double sizeBias = 2.4;

  /// Brightest a star gets (0..1).
  static const double maxOpacity = 0.9;

  /// Each star fades on and off over a random time in this range.
  static const Duration minTwinkle = Duration(milliseconds: 2800);
  static const Duration maxTwinkle = Duration(milliseconds: 8000);

  /// Above 1 keeps stars dark for longer between flickers.
  static const double offBias = 1.6;

  /// Soft glow around the bigger stars, 0 = none.
  static const double glow = 0.6;

  /// Change for a different sky.
  static const int seed = 11;
}
