import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ambient_tuning.dart';
import 'blur_tuning.dart';
import 'terminal_tuning.dart';
import 'ui_tuning.dart';
import 'xmb_tuning.dart';

/// One adjustable value in the developer settings.
class DevParam {
  DevParam(this.group, this.key, this.label, this.min, this.max, this.read,
      this.write,
      {this.decimals = 2, this.unit = ''})
      : def = read();

  final String group;
  final String key;
  final String label;
  final double min;
  final double max;
  final int decimals;
  final String unit;
  final double Function() read;
  final void Function(double) write;

  /// The value hardcoded in lib/debug/*_tuning.dart.
  final double def;

  bool get changed => (read() - def).abs() > 1e-9;
}

/// Developer settings: live overrides of the hardcoded tuning values
/// (lib/debug/*_tuning.dart), unlocked with a password from the logo at
/// the bottom of Settings. Overrides are saved on the phone and can be
/// exported as JSON, to be written back into the tuning files.
class DevValues {
  DevValues._();

  /// Bumped on every change, so things that cache tuning values (sparkle
  /// sizes, star field) know to recompute.
  static int version = 0;

  /// Notifies after every change (the player re-applies its effects).
  static final ValueNotifier<int> changes = ValueNotifier(0);

  static bool unlocked = false;
  static SharedPreferences? _prefs;

  // sha256 of the password, so the public repo does not contain it.
  static const _hash =
      '8cbf64dada91cc6e4aa744d2b1300744742416b204fa572f1cfcd4ba5bed55c0';

  static bool checkPassword(String input) =>
      sha256.convert(utf8.encode(input.trim())).toString() == _hash;

  static final List<DevParam> params = _build();

  static DevParam? byKey(String key) {
    for (final p in params) {
      if (p.key == key) return p;
    }
    return null;
  }

  /// Applies saved overrides. Call once at startup, before the UI.
  static void load(SharedPreferences prefs) {
    _prefs = prefs;
    unlocked = prefs.getBool('dev.unlocked') ?? false;
    for (final p in params) {
      final v = prefs.getDouble('dev.${p.key}');
      if (v != null) p.write(v);
    }
    _bump();
  }

  static void setUnlocked(bool v) {
    unlocked = v;
    _prefs?.setBool('dev.unlocked', v);
    _bump();
  }

  static void setValue(DevParam p, double v) {
    p.write(v.clamp(p.min, p.max).toDouble());
    _bump();
  }

  /// Saves one value (called when a slider is released).
  static void save(DevParam p) {
    if (p.changed) {
      _prefs?.setDouble('dev.${p.key}', p.read());
    } else {
      _prefs?.remove('dev.${p.key}');
    }
  }

  static void reset(DevParam p) {
    p.write(p.def);
    _prefs?.remove('dev.${p.key}');
    _bump();
  }

  static void resetAll() {
    for (final p in params) {
      p.write(p.def);
      _prefs?.remove('dev.${p.key}');
    }
    _bump();
  }

  static double _round(DevParam p, double v) =>
      double.parse(v.toStringAsFixed(p.decimals + 2));

  /// Every value, plus the ones that differ from the hardcoded defaults.
  static String exportJson() {
    final all = <String, double>{};
    final changed = <String, Map<String, double>>{};
    for (final p in params) {
      all[p.key] = _round(p, p.read());
      if (p.changed) {
        changed[p.key] = {'from': _round(p, p.def), 'to': _round(p, p.read())};
      }
    }
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'muslic',
      'kind': 'dev-settings',
      'changed': changed,
      'values': all,
    });
  }

  /// Loads values from [exportJson] output. Returns how many were applied.
  static int importJson(String text) {
    final data = jsonDecode(text);
    final values = data is Map && data['values'] is Map
        ? data['values'] as Map
        : data as Map;
    var n = 0;
    values.forEach((k, v) {
      final p = byKey('$k');
      if (p != null && v is num) {
        p.write(v.toDouble().clamp(p.min, p.max).toDouble());
        save(p);
        n++;
      }
    });
    _bump();
    return n;
  }

  static void _bump() {
    version++;
    changes.value = version;
  }

  // ---- The list --------------------------------------------------------

  // Gradient colours are edited as hue/saturation/value. The triples are
  // kept here so hue survives while saturation or value is zero.
  static final Map<String, List<double>> _hsv = {};

  static List<double> _hsvOf(String id, List<Color> list, int i) =>
      _hsv.putIfAbsent(id, () {
        final h = HSVColor.fromColor(list[i]);
        return [h.hue, h.saturation, h.value];
      });

  static List<DevParam> _build() {
    final out = <DevParam>[];

    void d(String group, String key, String label, double min, double max,
            double Function() rd, void Function(double) wr,
            {int dec = 2, String unit = ''}) =>
        out.add(DevParam(group, key, label, min, max, rd, wr,
            decimals: dec, unit: unit));

    void ms(String group, String key, String label, double min, double max,
            Duration Function() rd, void Function(Duration) wr) =>
        d(group, key, label, min, max, () => rd().inMilliseconds.toDouble(),
            (v) => wr(Duration(milliseconds: v.round())),
            dec: 0, unit: 'ms');

    void colour(String group, String id, String label, List<Color> list,
        int i) {
      List<double> hsv() => _hsvOf(id, list, i);
      void apply() {
        final c = hsv();
        list[i] = HSVColor.fromAHSV(1, c[0], c[1], c[2]).toColor();
      }

      d(group, '$id.hue', '$label hue', 0, 360, () => hsv()[0],
          (v) {
        hsv()[0] = v;
        apply();
      }, dec: 0, unit: '°');
      d(group, '$id.sat', '$label saturation', 0, 1, () => hsv()[1], (v) {
        hsv()[1] = v;
        apply();
      });
      d(group, '$id.val', '$label brightness', 0, 1, () => hsv()[2], (v) {
        hsv()[2] = v;
        apply();
      });
    }

    // Sound and vibration.
    const sv = 'Scroll sound and vibration';
    d(sv, 'scroll.volume', 'Click volume', 0, 1,
        () => ScrollSoundTuning.volume, (v) => ScrollSoundTuning.volume = v);
    ms(sv, 'scroll.minGap', 'Click minimum gap', 0, 150,
        () => ScrollSoundTuning.minGap, (v) => ScrollSoundTuning.minGap = v);
    d(sv, 'haptic.amplitude', 'Vibration strength', 1, 255,
        () => HapticTuning.amplitude.toDouble(),
        (v) => HapticTuning.amplitude = v.round(),
        dec: 0);
    d(sv, 'haptic.length', 'Vibration length', 1, 80,
        () => HapticTuning.lengthMs.toDouble(),
        (v) => HapticTuning.lengthMs = v.round(),
        dec: 0, unit: 'ms');
    ms(sv, 'haptic.minGap', 'Vibration minimum gap', 0, 150,
        () => HapticTuning.minGap, (v) => HapticTuning.minGap = v);

    // Ambient.
    const am = 'Ambient mode';
    d(am, 'ambient.speed', 'Speed', 0.5, 1.2, () => AmbientTuning.speed,
        (v) => AmbientTuning.speed = v);
    d(am, 'ambient.pitch', 'Pitch', 0.5, 1.2, () => AmbientTuning.pitch,
        (v) => AmbientTuning.pitch = v);
    ms(am, 'ambient.ramp', 'Slow-down glide', 0, 4000,
        () => AmbientTuning.ramp, (v) => AmbientTuning.ramp = v);
    d(am, 'ambient.dry', 'Dry (original) level', 0, 1.2,
        () => AmbientTuning.dry, (v) => AmbientTuning.dry = v);
    d(am, 'ambient.reverbWet', 'Reverb level', 0, 0.6,
        () => AmbientTuning.reverbWet, (v) => AmbientTuning.reverbWet = v,
        dec: 3);
    d(am, 'ambient.roomSize', 'Reverb room size', 0, 0.98,
        () => AmbientTuning.roomSize, (v) => AmbientTuning.roomSize = v);
    d(am, 'ambient.damping', 'Reverb damping', 0, 1,
        () => AmbientTuning.damping, (v) => AmbientTuning.damping = v);
    d(am, 'ambient.width', 'Reverb width', 0, 1, () => AmbientTuning.width,
        (v) => AmbientTuning.width = v);
    d(am, 'ambient.preDelay', 'Reverb pre-delay', 0, 250,
        () => AmbientTuning.preDelayMs, (v) => AmbientTuning.preDelayMs = v,
        dec: 0, unit: 'ms');
    d(am, 'ambient.echoWet', 'Echo level', 0, 0.6,
        () => AmbientTuning.echoWet, (v) => AmbientTuning.echoWet = v,
        dec: 3);
    d(am, 'ambient.echoMs', 'Echo delay', 1, 2000,
        () => AmbientTuning.echoMs, (v) => AmbientTuning.echoMs = v,
        dec: 0, unit: 'ms');
    d(am, 'ambient.echoFeedback', 'Echo feedback', 0, 0.95,
        () => AmbientTuning.echoFeedback,
        (v) => AmbientTuning.echoFeedback = v);
    d(am, 'ambient.echoTone', 'Echo tone (low-pass)', 500, 12000,
        () => AmbientTuning.echoToneHz, (v) => AmbientTuning.echoToneHz = v,
        dec: 0, unit: 'Hz');
    d(am, 'ambient.fxFade', 'Effects fade', 0, 3000,
        () => AmbientTuning.fxFadeMs, (v) => AmbientTuning.fxFadeMs = v,
        dec: 0, unit: 'ms');

    // Reverb / Echo toggles.
    const fx = 'Reverb and Echo toggles';
    d(fx, 'fx.onLevel', '"On" level', 0, 1, () => FxTuning.onLevel,
        (v) => FxTuning.onLevel = v);
    d(fx, 'fx.reverbWetMax', 'Reverb level at 100%', 0, 0.8,
        () => FxTuning.reverbWetMax, (v) => FxTuning.reverbWetMax = v,
        dec: 3);
    d(fx, 'fx.roomSize', 'Reverb room size', 0, 0.98,
        () => FxTuning.roomSize, (v) => FxTuning.roomSize = v);
    d(fx, 'fx.damping', 'Reverb damping', 0, 1, () => FxTuning.damping,
        (v) => FxTuning.damping = v);
    d(fx, 'fx.width', 'Reverb width', 0, 1, () => FxTuning.width,
        (v) => FxTuning.width = v);
    d(fx, 'fx.preDelay', 'Reverb pre-delay', 0, 250,
        () => FxTuning.preDelayMs, (v) => FxTuning.preDelayMs = v,
        dec: 0, unit: 'ms');
    d(fx, 'fx.echoWetMax', 'Echo level at 100%', 0, 0.9,
        () => FxTuning.echoWetMax, (v) => FxTuning.echoWetMax = v, dec: 3);
    d(fx, 'fx.echoMs', 'Echo delay', 1, 2000, () => FxTuning.echoMs,
        (v) => FxTuning.echoMs = v,
        dec: 0, unit: 'ms');
    d(fx, 'fx.echoFeedback', 'Echo feedback', 0, 0.95,
        () => FxTuning.echoFeedback, (v) => FxTuning.echoFeedback = v);
    d(fx, 'fx.echoTone', 'Echo tone (low-pass)', 500, 12000,
        () => FxTuning.echoToneHz, (v) => FxTuning.echoToneHz = v,
        dec: 0, unit: 'Hz');
    d(fx, 'fx.duckReverb', 'Dry lowered by reverb', 0, 1,
        () => FxTuning.dryDuckReverb, (v) => FxTuning.dryDuckReverb = v);
    d(fx, 'fx.duckEcho', 'Dry lowered by echo', 0, 1,
        () => FxTuning.dryDuckEcho, (v) => FxTuning.dryDuckEcho = v);
    d(fx, 'fx.fade', 'Toggle fade', 0, 2000, () => FxTuning.fadeMs,
        (v) => FxTuning.fadeMs = v,
        dec: 0, unit: 'ms');

    // Wave background colours.
    const xc = 'Wave background colours';
    for (var i = 0; i < 3; i++) {
      colour(xc, 'xmb.light$i', 'Light ${i + 1}', XmbTuning.lightGradient, i);
    }
    for (var i = 0; i < 3; i++) {
      colour(xc, 'xmb.dark$i', 'Dark ${i + 1}', XmbTuning.darkGradient, i);
    }
    d(xc, 'xmb.gradientMid', 'Middle colour position', 0.05, 0.95,
        () => XmbTuning.gradientMid, (v) => XmbTuning.gradientMid = v);

    // Wave wave.
    const xw = 'Wave: the wave';
    d(xw, 'xmb.centre', 'Centre (of width)', -0.2, 1.2,
        () => XmbTuning.centre, (v) => XmbTuning.centre = v);
    d(xw, 'xmb.lean', 'Lean', -0.6, 0.6, () => XmbTuning.lean,
        (v) => XmbTuning.lean = v);
    d(xw, 'xmb.spread', 'Width', 0, 0.5, () => XmbTuning.spread,
        (v) => XmbTuning.spread = v, dec: 3);
    d(xw, 'xmb.spreadLean', 'Width growth', -0.2, 0.2,
        () => XmbTuning.spreadLean, (v) => XmbTuning.spreadLean = v, dec: 3);
    for (var i = 0; i < XmbTuning.waves.length; i++) {
      final w = XmbTuning.waves[i];
      final n = 'Wave ${i + 1}';
      d(xw, 'xmb.wave$i.amp', '$n size', 0, 0.2, () => w.amp,
          (v) => w.amp = v, dec: 3);
      d(xw, 'xmb.wave$i.along', '$n frequency', 0, 10, () => w.along,
          (v) => w.along = v);
      d(xw, 'xmb.wave$i.twist', '$n twist', -8, 8, () => w.twist,
          (v) => w.twist = v);
      d(xw, 'xmb.wave$i.speed', '$n speed', -2, 2, () => w.speed,
          (v) => w.speed = v);
      d(xw, 'xmb.wave$i.phase', '$n phase', 0, 6.3, () => w.phase,
          (v) => w.phase = v);
    }
    d(xw, 'xmb.flowSpeed', 'Flow speed', 0, 4, () => XmbTuning.flowSpeed,
        (v) => XmbTuning.flowSpeed = v);
    d(xw, 'xmb.opacityLight', 'Opacity (light)', 0, 1,
        () => XmbTuning.opacityLight, (v) => XmbTuning.opacityLight = v);
    d(xw, 'xmb.opacityDark', 'Opacity (dark)', 0, 1,
        () => XmbTuning.opacityDark, (v) => XmbTuning.opacityDark = v);
    d(xw, 'xmb.baseAlpha', 'Fill where facing you', 0, 0.5,
        () => XmbTuning.baseAlpha, (v) => XmbTuning.baseAlpha = v, dec: 3);
    d(xw, 'xmb.fresnel', 'Fold brightness', 0, 2, () => XmbTuning.fresnel,
        (v) => XmbTuning.fresnel = v);
    d(xw, 'xmb.fresnelPower', 'Fold sharpness', 0.2, 8,
        () => XmbTuning.fresnelPower, (v) => XmbTuning.fresnelPower = v);
    d(xw, 'xmb.backBoost', 'Back of fold brightness', 0, 0.5,
        () => XmbTuning.backBoost, (v) => XmbTuning.backBoost = v, dec: 3);
    d(xw, 'xmb.depth', 'Depth', 0.02, 1, () => XmbTuning.depth,
        (v) => XmbTuning.depth = v, dec: 3);

    // Wave scrolling.
    const xs = 'Wave scrolling';
    d(xs, 'xmb.waveScroll', 'Wave scroll speed', 0, 1.5,
        () => XmbTuning.waveScroll, (v) => XmbTuning.waveScroll = v);
    d(xs, 'xmb.particleScrollMin', 'Small sparkle scroll speed', 0, 2,
        () => XmbTuning.particleScrollMin,
        (v) => XmbTuning.particleScrollMin = v);
    d(xs, 'xmb.particleScrollMax', 'Big sparkle scroll speed', 0, 2,
        () => XmbTuning.particleScrollMax,
        (v) => XmbTuning.particleScrollMax = v);
    d(xs, 'xmb.energyPerPx', 'Energy per scrolled point', 0, 0.01,
        () => XmbTuning.energyPerPx, (v) => XmbTuning.energyPerPx = v,
        dec: 4);
    d(xs, 'xmb.energyPerSong', 'Energy per song passed', 0, 0.5,
        () => XmbTuning.energyPerSong, (v) => XmbTuning.energyPerSong = v,
        dec: 3);
    d(xs, 'xmb.energyMax', 'Energy maximum', 0, 4, () => XmbTuning.energyMax,
        (v) => XmbTuning.energyMax = v);
    d(xs, 'xmb.energySpeedBoost', 'Energy: speed boost', 0, 6,
        () => XmbTuning.energySpeedBoost,
        (v) => XmbTuning.energySpeedBoost = v);
    d(xs, 'xmb.energyAmpBoost', 'Energy: size boost', 0, 2,
        () => XmbTuning.energyAmpBoost, (v) => XmbTuning.energyAmpBoost = v);
    ms(xs, 'xmb.energyDecay', 'Energy calm-down', 100, 5000,
        () => XmbTuning.energyDecay, (v) => XmbTuning.energyDecay = v);

    // Wave sparkles.
    const xp = 'Wave sparkles';
    d(xp, 'xmb.minSize', 'Smallest size', 0.2, 6, () => XmbTuning.minSize,
        (v) => XmbTuning.minSize = v);
    d(xp, 'xmb.maxSize', 'Biggest size', 0.2, 8, () => XmbTuning.maxSize,
        (v) => XmbTuning.maxSize = v);
    d(xp, 'xmb.sizeBias', 'More small ones', 0.5, 6,
        () => XmbTuning.sizeBias, (v) => XmbTuning.sizeBias = v);
    d(xp, 'xmb.particleOpacityLight', 'Brightness (light)', 0, 1,
        () => XmbTuning.particleOpacityLight,
        (v) => XmbTuning.particleOpacityLight = v);
    d(xp, 'xmb.particleOpacityDark', 'Brightness (dark)', 0, 1,
        () => XmbTuning.particleOpacityDark,
        (v) => XmbTuning.particleOpacityDark = v);
    d(xp, 'xmb.drift', 'Drift speed', 0, 80, () => XmbTuning.drift,
        (v) => XmbTuning.drift = v, dec: 0);
    ms(xp, 'xmb.minTwinkle', 'Twinkle fastest', 300, 10000,
        () => XmbTuning.minTwinkle, (v) => XmbTuning.minTwinkle = v);
    ms(xp, 'xmb.maxTwinkle', 'Twinkle slowest', 300, 15000,
        () => XmbTuning.maxTwinkle, (v) => XmbTuning.maxTwinkle = v);
    d(xp, 'xmb.repelRadius', 'Finger push radius', 0, 0.8,
        () => XmbTuning.repelRadius, (v) => XmbTuning.repelRadius = v);
    d(xp, 'xmb.repelForce', 'Finger push strength', 0, 8000,
        () => XmbTuning.repelForce, (v) => XmbTuning.repelForce = v, dec: 0);
    d(xp, 'xmb.wind', 'Carried by finger', 0, 1.5, () => XmbTuning.wind,
        (v) => XmbTuning.wind = v);
    d(xp, 'xmb.damping', 'Slow-down after push', 0.1, 10,
        () => XmbTuning.particleDamping,
        (v) => XmbTuning.particleDamping = v);
    d(xp, 'xmb.playerBg', 'Player background opacity', 0, 1,
        () => XmbTuning.playerBackgroundOpacity,
        (v) => XmbTuning.playerBackgroundOpacity = v);

    // Ambient stars.
    const st = 'Ambient stars (Classic)';
    d(st, 'stars.minRadius', 'Smallest size', 0.2, 4,
        () => StarTuning.minRadius, (v) => StarTuning.minRadius = v);
    d(st, 'stars.maxRadius', 'Biggest size', 0.2, 6,
        () => StarTuning.maxRadius, (v) => StarTuning.maxRadius = v);
    d(st, 'stars.sizeBias', 'More small ones', 0.5, 6,
        () => StarTuning.sizeBias, (v) => StarTuning.sizeBias = v);
    d(st, 'stars.maxOpacity', 'Brightness', 0, 1,
        () => StarTuning.maxOpacity, (v) => StarTuning.maxOpacity = v);
    ms(st, 'stars.minTwinkle', 'Twinkle fastest', 300, 15000,
        () => StarTuning.minTwinkle, (v) => StarTuning.minTwinkle = v);
    ms(st, 'stars.maxTwinkle', 'Twinkle slowest', 300, 20000,
        () => StarTuning.maxTwinkle, (v) => StarTuning.maxTwinkle = v);
    d(st, 'stars.offBias', 'Time spent dark', 0.5, 4,
        () => StarTuning.offBias, (v) => StarTuning.offBias = v);
    d(st, 'stars.glow', 'Glow', 0, 2, () => StarTuning.glow,
        (v) => StarTuning.glow = v);

    // CD.
    const cd = 'Ambient CD';
    ms(cd, 'cd.spinPeriod', 'Time per turn', 2000, 60000,
        () => CdTuning.spinPeriod, (v) => CdTuning.spinPeriod = v);
    ms(cd, 'cd.spinRamp', 'Spin up / slow down', 0, 5000,
        () => CdTuning.spinRamp, (v) => CdTuning.spinRamp = v);
    d(cd, 'cd.caseScale', 'Case size', 0.8, 1.3, () => CdTuning.caseScale,
        (v) => CdTuning.caseScale = v, dec: 3);
    d(cd, 'cd.discSize', 'Disc size', 0.5, 1, () => CdTuning.discSize,
        (v) => CdTuning.discSize = v, dec: 3);
    d(cd, 'cd.discX', 'Disc centre X', 0.4, 0.6, () => CdTuning.discCentreX,
        (v) => CdTuning.discCentreX = v, dec: 3);
    d(cd, 'cd.discY', 'Disc centre Y', 0.4, 0.6, () => CdTuning.discCentreY,
        (v) => CdTuning.discCentreY = v, dec: 3);
    d(cd, 'cd.hole', 'Hole size', 0, 0.3, () => CdTuning.holeSize,
        (v) => CdTuning.holeSize = v, dec: 3);
    d(cd, 'cd.caseOpacity', 'Case strength', 0, 1,
        () => CdTuning.caseOpacity, (v) => CdTuning.caseOpacity = v);

    // Player.
    const pl = 'Player';
    d(pl, 'blur.collapsedZoom', 'Mini player background zoom', 1, 1.6,
        () => BlurTuning.collapsedZoom, (v) => BlurTuning.collapsedZoom = v,
        dec: 3);
    d(pl, 'blur.expandedZoom', 'Player background zoom', 1, 1.6,
        () => BlurTuning.expandedZoom, (v) => BlurTuning.expandedZoom = v,
        dec: 3);
    d(pl, 'blur.collapsedDarken', 'Mini player darkening', 0, 0.8,
        () => BlurTuning.collapsedDarken,
        (v) => BlurTuning.collapsedDarken = v, dec: 3);
    d(pl, 'blur.expandedDarken', 'Player darkening', 0, 0.8,
        () => BlurTuning.expandedDarken, (v) => BlurTuning.expandedDarken = v,
        dec: 3);
    d(pl, 'swipe.distance', 'Art swipe distance', 0.05, 0.6,
        () => ArtSwipeTuning.distance, (v) => ArtSwipeTuning.distance = v);
    d(pl, 'swipe.fling', 'Art swipe flick speed', 100, 3000,
        () => ArtSwipeTuning.flingVelocity,
        (v) => ArtSwipeTuning.flingVelocity = v,
        dec: 0);
    ms(pl, 'swipe.out', 'Art swipe out', 50, 800, () => ArtSwipeTuning.out,
        (v) => ArtSwipeTuning.out = v);
    ms(pl, 'swipe.back', 'Art swipe in', 50, 1200, () => ArtSwipeTuning.back,
        (v) => ArtSwipeTuning.back = v);

    // Buttons and carousel.
    const bc = 'Buttons and carousel';
    d(bc, 'button.pressedScale', 'Button press size', 0.6, 1,
        () => ButtonTuning.pressedScale, (v) => ButtonTuning.pressedScale = v);
    ms(bc, 'button.pressIn', 'Button press time', 0, 300,
        () => ButtonTuning.pressIn, (v) => ButtonTuning.pressIn = v);
    d(bc, 'button.stiffness', 'Button spring stiffness', 50, 1500,
        () => ButtonTuning.springStiffness,
        (v) => ButtonTuning.springStiffness = v,
        dec: 0);
    d(bc, 'button.damping', 'Button spring damping', 1, 60,
        () => ButtonTuning.springDamping,
        (v) => ButtonTuning.springDamping = v,
        dec: 1);
    d(bc, 'carousel.fadeStart', 'Cover fade-out start (songs)', 1, 3.5,
        () => CarouselTuning.fadeStart, (v) => CarouselTuning.fadeStart = v);
    d(bc, 'carousel.fadeEnd', 'Cover fade-out end (songs)', 1.2, 3.5,
        () => CarouselTuning.fadeEnd, (v) => CarouselTuning.fadeEnd = v);
    ms(bc, 'carousel.tapScroll', 'Tap-to-scroll time', 50, 1500,
        () => CarouselTuning.tapScroll, (v) => CarouselTuning.tapScroll = v);
    ms(bc, 'carousel.restoreBase', 'Launch scroll base time', 0, 2000,
        () => CarouselTuning.restoreScrollBase,
        (v) => CarouselTuning.restoreScrollBase = v);
    ms(bc, 'carousel.restorePerSong', 'Launch scroll per song', 0, 300,
        () => CarouselTuning.restoreScrollPerSong,
        (v) => CarouselTuning.restoreScrollPerSong = v);
    ms(bc, 'carousel.restoreMax', 'Launch scroll maximum', 100, 5000,
        () => CarouselTuning.restoreScrollMax,
        (v) => CarouselTuning.restoreScrollMax = v);

    // Terminal theme.
    const tm = 'Terminal';
    d(tm, 'term.buttonVolume', 'Button sound volume', 0, 1,
        () => TerminalTuning.buttonSoundVolume,
        (v) => TerminalTuning.buttonSoundVolume = v);
    ms(tm, 'term.open', 'TV pull-out time', 100, 1500,
        () => TerminalTuning.open, (v) => TerminalTuning.open = v);
    d(tm, 'term.gradientLib', 'Green gradient end (library)', 0.1, 1,
        () => TerminalTuning.gradientEndLibrary,
        (v) => TerminalTuning.gradientEndLibrary = v);
    d(tm, 'term.glow', 'Title glow', 0, 120,
        () => TerminalTuning.titleGlowBlur,
        (v) => TerminalTuning.titleGlowBlur = v,
        dec: 0);

    const tc = 'Terminal carousel (TV out)';
    const names = ['centre', 'next', 'outer', 'beyond'];
    void table(String key, String label, List<double> list, double min,
        double max, int dec) {
      for (var i = 0; i < list.length; i++) {
        d(tc, 'term.$key$i', '$label (${names[i]})', min, max,
            () => list[i], (v) => list[i] = v,
            dec: dec);
      }
    }

    table('size', 'Size', TerminalTuning.hSize, 100, 900, 0);
    table('offset', 'Distance', TerminalTuning.hOffset, 0, 1200, 0);
    table('angle', 'Turn', TerminalTuning.hAngle, 0, 85, 0);
    table('wash', 'White wash', TerminalTuning.hWash, 0, 1, 2);
    table('opacity', 'Opacity', TerminalTuning.hOpacity, 0, 1, 2);
    d(tc, 'term.perspective', 'Perspective', 0, 0.004,
        () => TerminalTuning.hPerspective,
        (v) => TerminalTuning.hPerspective = v,
        dec: 4);
    d(tc, 'term.centreAt', 'Row height position', 0, 1,
        () => TerminalTuning.hCentreAt, (v) => TerminalTuning.hCentreAt = v);

    void crt(String id, String label, CrtParams p) {
      final g = 'Terminal CRT: $label';
      void c(String k, String l, double min, double max,
              double Function() rd, void Function(double) wr,
              {int dec = 1}) =>
          d(g, 'crt.$id.$k', l, min, max, rd, wr, dec: dec);
      c('curvature', 'Curvature', 0, 100, () => p.curvature,
          (v) => p.curvature = v, dec: 0);
      c('scanlines', 'Scanlines', 0, 100, () => p.scanlines,
          (v) => p.scanlines = v, dec: 0);
      c('scanSize', 'Scanline size', 1, 32, () => p.scanlineSize,
          (v) => p.scanlineSize = v);
      c('mask', 'RGB grille', 0, 100, () => p.mask, (v) => p.mask = v,
          dec: 0);
      c('maskPitch', 'RGB grille size', 2, 12, () => p.maskPitch,
          (v) => p.maskPitch = v);
      c('aberration', 'Colour fringing', 0, 100, () => p.aberration,
          (v) => p.aberration = v, dec: 0);
      c('flicker', 'Flicker', 0, 100, () => p.flicker,
          (v) => p.flicker = v, dec: 0);
      c('noise', 'Static', 0, 100, () => p.noise, (v) => p.noise = v,
          dec: 0);
      c('noiseSize', 'Static size', 1, 8, () => p.noiseSize,
          (v) => p.noiseSize = v);
      c('roll', 'Refresh bar speed', 0, 5, () => p.rollSpeed,
          (v) => p.rollSpeed = v, dec: 2);
      c('jitter', 'Jitter', 0, 100, () => p.jitter, (v) => p.jitter = v);
      c('vignette', 'Vignette', 0, 100, () => p.vignette,
          (v) => p.vignette = v, dec: 0);
      c('brightness', 'Brightness', -1, 1, () => p.brightness,
          (v) => p.brightness = v, dec: 2);
      c('speed', 'Animation speed', 0, 3, () => p.speed,
          (v) => p.speed = v, dec: 2);
    }

    crt('screen', 'whole screen', TerminalTuning.screen);
    crt('tvArt', 'TV album art', TerminalTuning.tvArt);
    crt('tvEq', 'TV equalizer', TerminalTuning.tvEqualizer);
    crt('miniArt', 'bar album art', TerminalTuning.miniArt);
    crt('miniTitle', 'bar title', TerminalTuning.miniTitle);
    crt('miniTime', 'bar time', TerminalTuning.miniTime);

    return out;
  }
}
