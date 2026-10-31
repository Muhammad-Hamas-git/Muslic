package com.ryanheise.just_audio;

import android.content.Context;
import android.os.Build;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.os.VibratorManager;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import java.util.Map;

/**
 * müslic addition: one shared {@link FxAudioProcessor} for the app, plus the
 * method channel "com.dotstudios.muslic/fx" that Dart uses to set it
 * (lib/services/audio_fx.dart). Also plays the short vibration ticks of
 * the carousel (lib/services/haptics.dart), since Flutter's own haptics
 * cannot set a length.
 */
public final class MuslicFx {
  private MuslicFx() {}

  static final FxAudioProcessor PROCESSOR = new FxAudioProcessor();

  private static Vibrator vibrator;

  static void register(BinaryMessenger messenger, Context context) {
    Context app = context.getApplicationContext();
    try {
      if (Build.VERSION.SDK_INT >= 31) {
        VibratorManager vm =
            (VibratorManager) app.getSystemService(Context.VIBRATOR_MANAGER_SERVICE);
        vibrator = vm != null ? vm.getDefaultVibrator() : null;
      } else {
        vibrator = (Vibrator) app.getSystemService(Context.VIBRATOR_SERVICE);
      }
    } catch (Exception e) {
      vibrator = null;
    }
    MethodChannel channel = new MethodChannel(messenger, "com.dotstudios.muslic/fx");
    channel.setMethodCallHandler((call, result) -> {
      if ("setParams".equals(call.method)) {
        Map<?, ?> a = (Map<?, ?>) call.arguments;
        PROCESSOR.setParams(
            f(a, "dry", 1f), f(a, "reverbWet", 0f), f(a, "roomSize", 0.85f),
            f(a, "damping", 0.4f), f(a, "width", 1f), f(a, "preDelayMs", 20f),
            f(a, "delayWet", 0f), f(a, "delayMs", 380f), f(a, "feedback", 0.35f),
            f(a, "toneHz", 3500f), f(a, "smoothingMs", 120f));
        result.success(null);
      } else if ("haptic".equals(call.method)) {
        Map<?, ?> a = (Map<?, ?>) call.arguments;
        vibrate((long) f(a, "ms", 12f), (int) f(a, "amplitude", -1f));
        result.success(null);
      } else {
        result.notImplemented();
      }
    });
  }

  private static void vibrate(long ms, int amplitude) {
    Vibrator v = vibrator;
    if (v == null || !v.hasVibrator() || ms <= 0) return;
    try {
      if (Build.VERSION.SDK_INT >= 26) {
        int amp = amplitude > 0 && v.hasAmplitudeControl()
            ? Math.min(255, amplitude)
            : VibrationEffect.DEFAULT_AMPLITUDE;
        v.vibrate(VibrationEffect.createOneShot(ms, amp));
      } else {
        v.vibrate(ms);
      }
    } catch (Exception ignored) {
      // Vibration is a nicety; never let it break scrolling.
    }
  }

  private static float f(Map<?, ?> a, String key, float fallback) {
    Object v = a.get(key);
    return v instanceof Number ? ((Number) v).floatValue() : fallback;
  }
}
