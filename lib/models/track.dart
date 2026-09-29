import 'package:on_audio_query/on_audio_query.dart';

/// A single playable audio file discovered on device storage.
class Track {
  final int id;
  final String title;
  final String artist;
  final String album;
  final String path;
  final Duration duration;
  final DateTime dateModified;
  final String? fileExtension;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.path,
    required this.duration,
    required this.dateModified,
    this.fileExtension,
  });

  /// Parent folder of the file, normalized with a trailing slash removed.
  String get folder {
    final i = path.lastIndexOf('/');
    return i <= 0 ? '/' : path.substring(0, i);
  }

  factory Track.fromSong(SongModel s) => Track(
        id: s.id,
        title: s.title.trim().isEmpty ? s.displayNameWOExt : s.title,
        artist: (s.artist == null || s.artist == '<unknown>')
            ? 'Unknown artist'
            : s.artist!,
        album: (s.album == null || s.album == '<unknown>')
            ? 'Unknown album'
            : s.album!,
        path: s.data,
        duration: Duration(milliseconds: s.duration ?? 0),
        dateModified: DateTime.fromMillisecondsSinceEpoch(
            (s.dateModified ?? 0) * 1000),
        fileExtension: s.fileExtension,
      );

  String get durationLabel {
    final d = duration;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  }
}
