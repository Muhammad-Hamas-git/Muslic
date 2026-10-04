import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

import '../debug/blur_tuning.dart';
import '../models/track.dart';

/// Disk cache for album art, in two flavours:
///
///  * sharp: the artwork as JPEG, fetched lazily the first time a widget
///    asks for it (carousel tiles, player art, notification art).
///  * blurred: a small, pre-blurred JPEG used as the player background.
///    These are generated for the whole library in the background right
///    after a scan ([warm]), so playback never waits on a blur.
///
/// Files are keyed by track id + modification time, so a re-tagged file
/// gets fresh artwork. Blurred files additionally live in a folder named
/// after [BlurTuning.signature]; changing a baked blur value therefore
/// invalidates them and old folders are deleted on launch.
class ArtworkCache {
  ArtworkCache._(this._root);

  /// [root] is only for tests; the app uses its private support folder.
  static Future<ArtworkCache> open({Directory? root}) async {
    final dir =
        root ?? Directory('${(await getApplicationSupportDirectory()).path}/artwork');
    final cache = ArtworkCache._(dir);
    await cache._init();
    return cache;
  }

  static const int sharpSize = 800;
  static const int sharpQuality = 90;

  final Directory _root;
  final OnAudioQuery _query = OnAudioQuery();

  late final Directory _sharpDir;
  late final Directory _blurDir;
  late final Directory _noneDir;

  // File names known to exist on disk (loaded once at start, then kept in
  // sync), so lookups never touch the file system.
  final Set<String> _sharpFiles = {};
  final Set<String> _blurFiles = {};
  final Set<String> _noArt = {};

  final Map<String, ValueNotifier<File?>> _sharpNotifiers = {};
  final Map<String, ValueNotifier<File?>> _blurNotifiers = {};
  final Map<String, Future<File?>> _sharpInFlight = {};

  // Background blur queue. Priority entries (the playing song) jump ahead.
  final Queue<Track> _queue = Queue();
  final Queue<Track> _priority = Queue();
  final Set<String> _queued = {};
  final Set<String> _running = {};
  int _activeWorkers = 0;

  /// Progress of the current background pass, for the settings screen.
  final ValueNotifier<int> pending = ValueNotifier(0);

  static String _key(Track t) =>
      '${t.id}_${t.dateModified.millisecondsSinceEpoch ~/ 1000}';

  Future<void> _init() async {
    _sharpDir = Directory('${_root.path}/sharp_$sharpSize');
    _blurDir = Directory('${_root.path}/blur_${_hash(BlurTuning.signature)}');
    _noneDir = Directory('${_root.path}/none');
    for (final d in [_sharpDir, _blurDir, _noneDir]) {
      await d.create(recursive: true);
    }

    // Remove blur folders left over from older tuning values.
    await for (final e in _root.list()) {
      if (e is Directory &&
          e.path.split('/').last.startsWith('blur_') &&
          e.path != _blurDir.path) {
        unawaited(e.delete(recursive: true).catchError((_) => e));
      }
    }

    Future<void> index(Directory d, Set<String> into) async {
      await for (final e in d.list()) {
        if (e is File) into.add(e.path.split('/').last.split('.').first);
      }
    }

    await Future.wait([
      index(_sharpDir, _sharpFiles),
      index(_blurDir, _blurFiles),
      index(_noneDir, _noArt),
    ]);
  }

  static String _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16);
  }

  File _sharpFile(String key) => File('${_sharpDir.path}/$key.jpg');
  File _blurFile(String key) => File('${_blurDir.path}/$key.jpg');

  bool hasNoArt(Track t) => _noArt.contains(_key(t));

  // ---------------------------------------------------------------------
  // Sharp artwork
  // ---------------------------------------------------------------------

  /// The sharp artwork file if it is already on disk, else null.
  File? sharpIfReady(Track t) {
    final k = _key(t);
    return _sharpFiles.contains(k) ? _sharpFile(k) : null;
  }

  /// Listenable sharp artwork. Starts a fetch if needed; the value stays
  /// null for tracks without embedded art.
  ValueListenable<File?> sharp(Track t) {
    final k = _key(t);
    final n = _sharpNotifiers.putIfAbsent(
        k, () => ValueNotifier(sharpIfReady(t)));
    if (n.value == null && !_noArt.contains(k)) {
      sharpFile(t).then((f) => n.value = f);
    }
    return n;
  }

  /// Fetches (once) and returns the sharp artwork file.
  Future<File?> sharpFile(Track t) {
    final k = _key(t);
    final ready = sharpIfReady(t);
    if (ready != null) return SynchronousFuture(ready);
    if (_noArt.contains(k)) return SynchronousFuture(null);
    return _sharpInFlight.putIfAbsent(k, () async {
      try {
        final bytes = await _query.queryArtwork(
          t.id,
          ArtworkType.AUDIO,
          format: ArtworkFormat.JPEG,
          size: sharpSize,
          quality: sharpQuality,
        );
        if (bytes == null || bytes.isEmpty) {
          await _markNoArt(k);
          return null;
        }
        final f = _sharpFile(k);
        await f.writeAsBytes(bytes, flush: false);
        _sharpFiles.add(k);
        return f;
      } catch (e) {
        debugPrint('müslic artwork: ${t.id} failed: $e');
        return null;
      } finally {
        _sharpInFlight.remove(k);
      }
    });
  }

  Future<void> _markNoArt(String k) async {
    _noArt.add(k);
    try {
      await File('${_noneDir.path}/$k').create();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------
  // Blurred backgrounds
  // ---------------------------------------------------------------------

  File? blurIfReady(Track t) {
    final k = _key(t);
    return _blurFiles.contains(k) ? _blurFile(k) : null;
  }

  /// Listenable blurred background. If it is not generated yet (for
  /// example a song added since the last scan) it is queued with priority.
  ValueListenable<File?> blur(Track t) {
    final k = _key(t);
    final n =
        _blurNotifiers.putIfAbsent(k, () => ValueNotifier(blurIfReady(t)));
    if (n.value == null && !_noArt.contains(k)) {
      _enqueue(t, priority: true);
    }
    return n;
  }

  /// Queues blur generation for every track that does not have one yet.
  /// Called by the library after each scan.
  void warm(Iterable<Track> tracks) {
    for (final t in tracks) {
      _enqueue(t);
    }
  }

  void _enqueue(Track t, {bool priority = false}) {
    final k = _key(t);
    if (_blurFiles.contains(k) || _noArt.contains(k)) return;
    if (_queued.contains(k)) {
      if (priority) _priority.addFirst(t);
      _pump();
      return;
    }
    _queued.add(k);
    priority ? _priority.addFirst(t) : _queue.add(t);
    pending.value = _queued.length;
    _pump();
  }

  void _pump() {
    while (_activeWorkers < BlurTuning.workers &&
        (_priority.isNotEmpty || _queue.isNotEmpty)) {
      final t = _priority.isNotEmpty
          ? _priority.removeFirst()
          : _queue.removeFirst();
      final k = _key(t);
      // Skip duplicates (a track can sit in both queues) and finished items.
      if (!_queued.contains(k) || _running.contains(k)) continue;
      _running.add(k);
      _activeWorkers++;
      _process(t).whenComplete(() {
        _activeWorkers--;
        _running.remove(k);
        _queued.remove(k);
        pending.value = _queued.length;
        _pump();
      });
    }
  }

  Future<void> _process(Track t) async {
    final k = _key(t);
    if (_blurFiles.contains(k) || _noArt.contains(k)) return;
    try {
      // Platform calls must happen on the main isolate; the decoding and
      // blurring happen on a worker isolate.
      final bytes = await _query.queryArtwork(
        t.id,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: BlurTuning.sourceSize,
        quality: 90,
      );
      if (bytes == null || bytes.isEmpty) {
        await _markNoArt(k);
        _blurNotifiers[k]?.value = null;
        return;
      }
      final job = _BlurJob(
        bytes: bytes,
        workingSize: BlurTuning.workingSize,
        radius: BlurTuning.blurRadius,
        passes: BlurTuning.blurPasses,
        saturation: BlurTuning.saturation,
        brightness: BlurTuning.brightness,
        quality: BlurTuning.jpegQuality,
      );
      final out = await Isolate.run(() => _runBlur(job));
      if (out == null) {
        await _markNoArt(k);
        return;
      }
      final f = _blurFile(k);
      await f.writeAsBytes(out, flush: false);
      _blurFiles.add(k);
      _blurNotifiers[k]?.value = f;
    } catch (e) {
      debugPrint('müslic blur: ${t.id} failed: $e');
    }
  }

  /// Deletes every cached file. Used by "Clear artwork cache" in settings.
  Future<void> clear() async {
    _queue.clear();
    _priority.clear();
    _queued.clear();
    pending.value = 0;
    _sharpFiles.clear();
    _blurFiles.clear();
    _noArt.clear();
    for (final n in _sharpNotifiers.values) {
      n.value = null;
    }
    for (final n in _blurNotifiers.values) {
      n.value = null;
    }
    _sharpNotifiers.clear();
    _blurNotifiers.clear();
    try {
      await _root.delete(recursive: true);
    } catch (_) {}
    await _init();
  }
}

class _BlurJob {
  const _BlurJob({
    required this.bytes,
    required this.workingSize,
    required this.radius,
    required this.passes,
    required this.saturation,
    required this.brightness,
    required this.quality,
  });
  final Uint8List bytes;
  final int workingSize;
  final int radius;
  final int passes;
  final double saturation;
  final double brightness;
  final int quality;
}

/// Runs on a worker isolate.
Uint8List? _runBlur(_BlurJob j) {
  final src = img.decodeImage(j.bytes);
  if (src == null) return null;
  var im = img.copyResizeCropSquare(
    src,
    size: j.workingSize,
    interpolation: img.Interpolation.average,
  );
  for (var i = 0; i < j.passes; i++) {
    im = img.gaussianBlur(im, radius: j.radius);
  }
  if (j.saturation != 1.0 || j.brightness != 1.0) {
    im = img.adjustColor(im,
        saturation: j.saturation, brightness: j.brightness);
  }
  return img.encodeJpg(im, quality: j.quality);
}
