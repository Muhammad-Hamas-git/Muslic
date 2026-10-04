import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/track.dart';
import '../services/artwork_cache.dart';
import 'settings_controller.dart';

/// Wraps a single app-wide [AudioPlayer] with:
///  - queue management from the library carousel
///  - speed and independent pitch, both 0.5x to 2x
///  - a system equalizer (Android's built-in bands, usually 5)
///  - clip-safe boost via Android's LoudnessEnhancer, whose limiter
///    compresses peaks instead of hard-clipping
///  - background play and the media notification via just_audio_background
class PlayerController extends ChangeNotifier {
  PlayerController(this._settings, this._art) {
    _loudness = AndroidLoudnessEnhancer()..setEnabled(true);
    _eq = AndroidEqualizer()..setEnabled(_settings.eqEnabled);
    _player = AudioPlayer(
      audioPipeline: AudioPipeline(androidAudioEffects: [_loudness, _eq]),
      handleInterruptions: true,
    );

    if (_settings.rememberPlaybackSettings) {
      speed = _settings.lastSpeed;
      pitch = _settings.lastPitch;
      gainDb = _settings.lastGainDb;
    }
    eqEnabled = _settings.eqEnabled;

    _subs.add(_player.playerStateStream.listen((_) => notifyListeners()));
    _subs.add(_player.currentIndexStream.listen((_) => notifyListeners()));
    _subs.add(_player.loopModeStream.listen((_) => notifyListeners()));
    _subs.add(
        _player.shuffleModeEnabledStream.listen((_) => notifyListeners()));
    _subs.add(_player.playbackEventStream.listen((_) {},
        onError: (Object e, StackTrace st) {
      // Keep the session alive on a bad file; skip forward if possible.
      debugPrint('müslic playback error: $e');
      if (_player.hasNext) _player.seekToNext();
    }));
  }

  static const double minRate = 0.5;
  static const double maxRate = 2.0;

  final SettingsController _settings;
  final ArtworkCache _art;
  late final AudioPlayer _player;
  late final AndroidLoudnessEnhancer _loudness;
  late final AndroidEqualizer _eq;
  final List<StreamSubscription> _subs = [];

  List<Track> queue = [];
  double speed = 1.0;
  double pitch = 1.0;
  double gainDb = 0.0; // 0..+12 dB

  // Equalizer state. Bands are only known once audio has been loaded.
  bool eqEnabled = true;
  List<AndroidEqualizerBand> _eqBands = const [];
  List<double> eqFrequencies = const []; // Hz, one per band
  List<double> eqGains = const []; // dB, one per band
  double eqMinDb = -15;
  double eqMaxDb = 15;
  bool get eqReady => eqFrequencies.isNotEmpty;

  AudioPlayer get player => _player;
  bool get playing => _player.playing;
  Track? get current {
    final i = _player.currentIndex;
    if (i == null || i < 0 || i >= queue.length) return null;
    return queue[i];
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Duration get duration =>
      _player.duration ?? current?.duration ?? Duration.zero;

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
            artUri: _artUri(t),
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
      unawaited(_loadEqualizer());
    } catch (e) {
      debugPrint('müslic: failed to set queue: $e');
    }
    notifyListeners();
  }

  /// Notification / lock screen art. Uses the cached JPEG when present,
  /// which works on every Android version; the media-store URI is a
  /// fallback that only older versions resolve.
  Uri _artUri(Track t) {
    final f = _art.sharpIfReady(t);
    if (f != null) return Uri.file(f.path);
    _art.sharpFile(t); // warm it for next time
    return Uri.parse('content://media/external/audio/media/${t.id}/albumart');
  }

  Future<void> _applyParams() async {
    await _player.setSpeed(speed);
    await _player.setPitch(pitch);
    _loudness.setTargetGain(gainDb);
  }

  Future<void> _loadEqualizer() async {
    if (eqReady) return;
    try {
      final params = await _eq.parameters;
      eqMinDb = params.minDecibels;
      eqMaxDb = params.maxDecibels;
      _eqBands = params.bands;
      final saved = _settings.eqGains;
      for (var i = 0; i < _eqBands.length && i < saved.length; i++) {
        await _eqBands[i].setGain(saved[i].clamp(eqMinDb, eqMaxDb));
      }
      eqFrequencies = [for (final b in _eqBands) b.centerFrequency];
      eqGains = [for (final b in _eqBands) b.gain];
      notifyListeners();
    } catch (e) {
      debugPrint('müslic: equalizer unavailable: $e');
    }
  }

  Future<void> setBandGain(int band, double db) async {
    if (band < 0 || band >= _eqBands.length) return;
    final v = db.clamp(eqMinDb, eqMaxDb).toDouble();
    eqGains = List.of(eqGains)..[band] = v;
    notifyListeners();
    await _eqBands[band].setGain(v);
    _persistEq();
  }

  Future<void> setEqEnabled(bool v) async {
    eqEnabled = v;
    await _eq.setEnabled(v);
    _persistEq();
    notifyListeners();
  }

  Future<void> resetEqualizer() async {
    eqGains = [for (final _ in _eqBands) 0.0];
    notifyListeners();
    for (final b in _eqBands) {
      await b.setGain(0);
    }
    _persistEq();
  }

  void _persistEq() =>
      _settings.saveEqualizer(enabled: eqEnabled, gains: eqGains);

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
    speed = v.clamp(minRate, maxRate);
    await _player.setSpeed(speed);
    _persist();
    notifyListeners();
  }

  Future<void> setPitch(double v) async {
    pitch = v.clamp(minRate, maxRate);
    await _player.setPitch(pitch);
    _persist();
    notifyListeners();
  }

  void setGainDb(double v) {
    gainDb = v.clamp(0.0, 12.0);
    _loudness.setTargetGain(gainDb);
    _persist();
    notifyListeners();
  }

  Future<void> resetRates() async {
    speed = 1.0;
    pitch = 1.0;
    gainDb = 0.0;
    await _applyParams();
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
