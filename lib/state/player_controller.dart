import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/track.dart';
import 'settings_controller.dart';

/// Wraps a single app-wide [AudioPlayer] with:
///  - queue management from the library grid
///  - variable speed (0.25x–3x) and independent pitch (0.5x–2x)
///  - clip-safe amplification via Android's LoudnessEnhancer (its built-in
///    limiter compresses peaks instead of hard-clipping)
///  - background play + media notification via just_audio_background
class PlayerController extends ChangeNotifier {
  PlayerController(this._settings) {
    _loudness = AndroidLoudnessEnhancer();
    _loudness.setEnabled(true);
    _player = AudioPlayer(
      audioPipeline: AudioPipeline(androidAudioEffects: [_loudness]),
      handleInterruptions: true,
    );

    if (_settings.rememberPlaybackSettings) {
      speed = _settings.lastSpeed;
      pitch = _settings.lastPitch;
      gainDb = _settings.lastGainDb;
    }

    _subs.add(_player.playerStateStream.listen((_) => notifyListeners()));
    _subs.add(_player.currentIndexStream.listen((_) => notifyListeners()));
    _subs.add(_player.loopModeStream.listen((_) => notifyListeners()));
    _subs.add(_player.shuffleModeEnabledStream.listen((_) => notifyListeners()));
    _subs.add(_player.playbackEventStream.listen((_) {},
        onError: (Object e, StackTrace st) {
      // Keep the session alive on a bad file; skip forward if possible.
      debugPrint('müslic playback error: $e');
      if (_player.hasNext) _player.seekToNext();
    }));
  }

  final SettingsController _settings;
  late final AudioPlayer _player;
  late final AndroidLoudnessEnhancer _loudness;
  final List<StreamSubscription> _subs = [];

  List<Track> queue = [];
  double speed = 1.0;
  double pitch = 1.0;
  double gainDb = 0.0; // 0..+12 dB

  AudioPlayer get player => _player;
  bool get playing => _player.playing;
  Track? get current {
    final i = _player.currentIndex;
    if (i == null || i < 0 || i >= queue.length) return null;
    return queue[i];
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Duration get duration => _player.duration ?? current?.duration ?? Duration.zero;

  /// Load [tracks] as the queue and start playback at [startIndex].
  Future<void> playQueue(List<Track> tracks, int startIndex) async {
    queue = List.of(tracks);
    final sources = [
      for (final t in queue)
        AudioSource.uri(
          Uri.file(t.path),
          tag: MediaItem(
            id: t.id.toString(),
            title: t.title,
            artist: t.artist,
            album: t.album,
            duration: t.duration,
            artUri: Uri.parse(
                'content://media/external/audio/media/${t.id}/albumart'),
          ),
        ),
    ];
    try {
      await _player.setAudioSource(
        ConcatenatingAudioSource(children: sources),
        initialIndex: startIndex,
        initialPosition: Duration.zero,
      );
      await _applyParams();
      _player.play();
    } catch (e) {
      debugPrint('müslic: failed to set queue: $e');
    }
    notifyListeners();
  }

  Future<void> _applyParams() async {
    await _player.setSpeed(speed);
    await _player.setPitch(pitch);
    _setGain(gainDb);
  }

  // just_audio's AndroidLoudnessEnhancer.setTargetGain takes gain in decibels
  // as a double; the platform side converts to millibels for the Android
  // LoudnessEnhancer effect, whose internal limiter prevents hard clipping.
  void _setGain(double db) => _loudness.setTargetGain(db);

  Future<void> togglePlay() async {
    playing ? await _player.pause() : _player.play();
  }

  Future<void> next() => _player.seekToNext();
  Future<void> previous() async {
    if (_player.position.inSeconds > 3 || !_player.hasPrevious) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
  }

  Future<void> seek(Duration d) => _player.seek(d);

  Future<void> cycleLoopMode() async {
    const order = [LoopMode.off, LoopMode.all, LoopMode.one];
    final i = order.indexOf(_player.loopMode);
    await _player.setLoopMode(order[(i + 1) % order.length]);
  }

  LoopMode get loopMode => _player.loopMode;
  bool get shuffle => _player.shuffleModeEnabled;

  Future<void> toggleShuffle() async {
    final enable = !_player.shuffleModeEnabled;
    if (enable) await _player.shuffle();
    await _player.setShuffleModeEnabled(enable);
  }

  Future<void> setSpeed(double v) async {
    speed = v.clamp(0.25, 3.0);
    await _player.setSpeed(speed);
    _persist();
    notifyListeners();
  }

  Future<void> setPitch(double v) async {
    pitch = v.clamp(0.5, 2.0);
    await _player.setPitch(pitch);
    _persist();
    notifyListeners();
  }

  void setGainDb(double v) {
    gainDb = v.clamp(0.0, 12.0);
    _setGain(gainDb);
    _persist();
    notifyListeners();
  }

  Future<void> resetAdvanced() async {
    speed = 1.0;
    pitch = 1.0;
    gainDb = 0.0;
    await _applyParams();
    _setGain(0);
    _persist();
    notifyListeners();
  }

  void _persist() {
    if (_settings.rememberPlaybackSettings) {
      _settings.savePlaybackParams(speed: speed, pitch: pitch, gainDb: gainDb);
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}
