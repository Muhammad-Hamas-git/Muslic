import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../debug/dev_values.dart';
import '../debug/terminal_tuning.dart';
import '../debug/ui_tuning.dart';

/// The click that plays when the carousel passes a song: the soft click,
/// or a digital beep in the Terminal theme.
///
/// Each sound has a small pool of players ("voices", see
/// [ScrollSoundTuning]) so fast scrolls layer clicks on top of each other
/// instead of cutting the previous one off. Plays through audioplayers,
/// separately from the music player, and never takes audio focus, so the
/// music keeps playing underneath.
class NavSound {
  NavSound._();
  static final NavSound instance = NavSound._();

  static const _click = 'sounds/navigation.m4a';
  static const _beep = 'sounds/beep.wav';
  static const _down = 'sounds/button_down.wav';
  static const _up = 'sounds/button_up.wav';

  /// Off in widget tests, where there is no audio plugin.
  static bool enabled = true;

  final Map<String, _Pool> _pools = {};
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  bool _listening = false;

  static final _context = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.media,
      // Critical: requesting focus would pause the song on every click.
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  _Pool _pool(String asset) => _pools.putIfAbsent(
      asset,
      () => asset == _down || asset == _up
          ? _Pool(asset, voices: 3, volume: () => TerminalTuning.buttonSoundVolume)
          : _Pool(asset));

  /// Loads the Terminal buttons' press and release sounds.
  Future<void> preloadButtons() async {
    if (!enabled) return;
    await _pool(_down).load();
    await _pool(_up).load();
  }

  /// Mechanical button sound: [down] when pressed in, otherwise released.
  void button({required bool down}) {
    if (!enabled) return;
    final pool = _pool(down ? _down : _up);
    if (pool.voices.isEmpty) {
      pool.load();
      return;
    }
    final voice = pool.voices[pool.next];
    pool.next = (pool.next + 1) % pool.voices.length;
    voice.stop().then((_) => voice.resume()).catchError((Object e) {
      debugPrint('müslic: button sound failed: $e');
    });
  }

  /// Loads a sound into its voices. Safe to call more than once.
  Future<void> preload({bool beep = false}) {
    if (!enabled) return Future<void>.value();
    if (!_listening) {
      _listening = true;
      DevValues.changes.addListener(_applyVolume);
    }
    return _pool(beep ? _beep : _click).load();
  }

  void _applyVolume() {
    for (final p in _pools.values) {
      for (final v in p.voices) {
        v.setVolume(p.volume()).catchError((Object _) {});
      }
    }
  }

  /// Plays one click (or beep) on the next voice.
  void click({bool beep = false}) {
    if (!enabled) return;
    final pool = _pool(beep ? _beep : _click);
    if (pool.voices.isEmpty) {
      preload(beep: beep);
      return;
    }
    final now = DateTime.now();
    if (now.difference(_last) < ScrollSoundTuning.minGap) return;
    _last = now;
    final voice = pool.voices[pool.next];
    pool.next = (pool.next + 1) % pool.voices.length;
    // stop() then resume() restarts this voice; the others keep ringing.
    voice.stop().then((_) => voice.resume()).catchError((Object e) {
      debugPrint('müslic: click failed: $e');
    });
  }
}

class _Pool {
  _Pool(this.asset, {int? voices, double Function()? volume})
      : count = voices ?? ScrollSoundTuning.voices,
        volume = volume ?? (() => ScrollSoundTuning.volume);
  final String asset;
  final int count;
  final double Function() volume;
  final List<AudioPlayer> voices = [];
  int next = 0;
  Future<void>? _loading;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      await AudioPlayer.global.setAudioContext(NavSound._context);
      final tag = asset.hashCode.toRadixString(16);
      for (var i = 0; i < count; i++) {
        final p = AudioPlayer(playerId: 'muslic_nav_${tag}_$i');
        await p.setAudioContext(NavSound._context);
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setVolume(volume());
        await p.setSource(AssetSource(asset));
        voices.add(p);
      }
    } catch (e) {
      debugPrint('müslic: scroll sound unavailable: $e');
    }
  }
}
