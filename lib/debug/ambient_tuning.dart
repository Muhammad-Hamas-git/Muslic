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
