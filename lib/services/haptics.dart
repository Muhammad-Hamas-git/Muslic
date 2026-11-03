import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../debug/ui_tuning.dart';
import '../state/settings_controller.dart';

/// Short vibration ticks for the carousel. Plays through the app's own
/// Android channel (MuslicFx.java) because Flutter's HapticFeedback cannot
/// set a length. Tuning: [HapticTuning]; on/off and length are settings.
class Haptics {
  Haptics._();

  static const _channel = MethodChannel('com.dotstudios.muslic/fx');

  /// Off in widget tests, where there is no Android side.
  static bool enabled = true;

  static DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  /// One tick, [ms] long (default [HapticTuning.lengthMs]). [force] skips
  /// the rate limit (used when previewing).
  static void tick({int? ms, bool force = false}) {
    if (!enabled) return;
    final now = DateTime.now();
    if (!force && now.difference(_last) < HapticTuning.minGap) return;
    _last = now;
    _channel.invokeMethod('haptic', {
      'ms': ms ?? HapticTuning.lengthMs,
      'amplitude': HapticTuning.amplitude,
    }).catchError((Object e) {
      debugPrint('müslic: haptic failed: $e');
    });
  }

  /// A tick for a button press, if Settings > Vibration is on.
  static void button(BuildContext context) {
    bool on;
    try {
      on = context.read<SettingsController>().scrollHaptics;
    } catch (_) {
      on = false; // no settings above (some tests)
    }
    if (on) tick(force: true);
  }
}
