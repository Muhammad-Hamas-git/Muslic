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

  /// Level of the dry (original) signal. Slightly below 1 leaves headroom
  /// for the reverb and pushes the song "back into the room".
  static const double dry = 0.85;

  /// Reverb level, 0..1. 0.35 is lush; above 0.6 gets washy.
  static const double reverbWet = 0.38;

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
  static const double echoWet = 0.18;

  /// Time between repeats, in ms (1..2000). 300 to 450 suits slowed songs.
  static const double echoMs = 420;

  /// How much each repeat feeds the next, 0..0.95. Higher = more repeats.
  static const double echoFeedback = 0.32;

  /// Low-pass on the repeats, in Hz. Lower = darker, more "tape" echoes.
  static const double echoToneHz = 2800;

  /// How long the effects fade in and out, in ms.
  static const double fxFadeMs = 900;
}

/// The Reverb and Echo sliders in the equalizer panel. Each slider snaps to
/// [stops] (0 = off, 1 = full), which scale the "full" values below.
class FxTuning {
  FxTuning._();

  static const List<double> stops = [0, 0.25, 0.5, 0.75, 1.0];

  // Reverb at full (slider at 100%).
  static const double reverbWetMax = 0.55;
  static const double roomSize = 0.82;
  static const double damping = 0.4;
  static const double width = 1.0;
  static const double preDelayMs = 25;

  // Echo at full (slider at 100%).
  static const double echoWetMax = 0.45;
  static const double echoMs = 360;
  static const double echoFeedback = 0.38;
  static const double echoToneHz = 3500;

  /// Fade time when a slider moves, in ms.
  static const double fadeMs = 150;
}
