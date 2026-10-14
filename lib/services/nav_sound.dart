import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../debug/ui_tuning.dart';

/// The click that plays when the carousel passes a song.
///
/// Uses a small pool of players ("voices", see [ScrollSoundTuning]) so fast
/// scrolls layer clicks on top of each other instead of cutting the previous
/// one off. Plays through audioplayers, separately from the music player,
/// and never takes audio focus, so the music keeps playing underneath.
class NavSound {
  NavSound._();
  static final NavSound instance = NavSound._();

  static const _asset = 'sounds/navigation.m4a';

  /// Off in widget tests, where there is no audio plugin.
  static bool enabled = true;

  final List<AudioPlayer> _voices = [];
  int _next = 0;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void>? _loading;

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

  /// Loads the sound into every voice. Safe to call more than once.
  Future<void> preload() =>
      enabled ? (_loading ??= _load()) : Future<void>.value();

  Future<void> _load() async {
    try {
      await AudioPlayer.global.setAudioContext(_context);
      for (var i = 0; i < ScrollSoundTuning.voices; i++) {
        final p = AudioPlayer(playerId: 'muslic_nav_$i');
        await p.setAudioContext(_context);
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setVolume(ScrollSoundTuning.volume);
        await p.setSource(AssetSource(_asset));
        _voices.add(p);
      }
    } catch (e) {
      debugPrint('müslic: scroll sound unavailable: $e');
    }
  }

  /// Plays one click on the next voice (the oldest one if all are busy).
  void click() {
    if (!enabled) return;
    if (_voices.isEmpty) {
      preload();
      return;
    }
    final now = DateTime.now();
    if (now.difference(_last) < ScrollSoundTuning.minGap) return;
    _last = now;
    final voice = _voices[_next];
    _next = (_next + 1) % _voices.length;
    // stop() then resume() restarts this voice; the others keep ringing.
    voice.stop().then((_) => voice.resume()).catchError((Object e) {
      debugPrint('müslic: click failed: $e');
    });
  }
}
