import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Talks to the reverb + echo processor added to just_audio's Android code
/// (packages/just_audio/android/.../FxAudioProcessor.java).
class AudioFx {
  AudioFx._();

  static const _channel = MethodChannel('com.dotstudios.muslic/fx');

  static Future<void> apply({
    double dry = 1.0,
    double reverbWet = 0,
    double roomSize = 0.85,
    double damping = 0.4,
    double width = 1.0,
    double preDelayMs = 20,
    double delayWet = 0,
    double delayMs = 380,
    double feedback = 0.35,
    double toneHz = 3500,
    double fadeMs = 120,
  }) async {
    try {
      await _channel.invokeMethod('setParams', {
        'dry': dry,
        'reverbWet': reverbWet,
        'roomSize': roomSize,
        'damping': damping,
        'width': width,
        'preDelayMs': preDelayMs,
        'delayWet': delayWet,
        'delayMs': delayMs,
        'feedback': feedback,
        'toneHz': toneHz,
        'smoothingMs': fadeMs,
      });
    } catch (e) {
      // Not on Android (tests, other platforms): effects are simply off.
      debugPrint('müslic fx unavailable: $e');
    }
  }
}
