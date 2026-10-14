package com.ryanheise.just_audio;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import java.util.Map;

/**
 * müslic addition: one shared {@link FxAudioProcessor} for the app, plus the
 * method channel "com.dotstudios.muslic/fx" that Dart uses to set it
 * (lib/services/audio_fx.dart).
 */
public final class MuslicFx {
  private MuslicFx() {}

  static final FxAudioProcessor PROCESSOR = new FxAudioProcessor();

  static void register(BinaryMessenger messenger) {
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
      } else {
        result.notImplemented();
      }
    });
  }

  private static float f(Map<?, ?> a, String key, float fallback) {
    Object v = a.get(key);
    return v instanceof Number ? ((Number) v).floatValue() : fallback;
  }
}
