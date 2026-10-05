import 'package:on_audio_query/on_audio_query.dart';

import '../services/title_cleaner.dart';

/// A single playable audio file discovered on device storage.
///
/// [title] and [artist] are what the app shows (tidied by [TitleCleaner]
/// when that setting is on). [rawTitle] and [rawArtist] are the file's own
/// tags, kept for search.
class Track {
  final int id;
  final String title;
  final String artist;
  final String album;
  final String path;
  final Duration duration;
  final DateTime dateModified;
  final String? fileExtension;
  final String? _rawTitle;
  final String? _rawArtist;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.path,
    required this.duration,
    required this.dateModified,
    this.fileExtension,
    String? rawTitle,
    String? rawArtist,
  })  : _rawTitle = rawTitle,
        _rawArtist = rawArtist;

  String get rawTitle => _rawTitle ?? title;
  String get rawArtist => _rawArtist ?? artist;

  static const unknownArtist = 'Unknown artist';

  /// Parent folder of the file, normalized with a trailing slash removed.
  String get folder {
    final i = path.lastIndexOf('/');
    return i <= 0 ? '/' : path.substring(0, i);
  }

  factory Track.fromSong(SongModel s, {bool tidy = true}) {
    final rawTitle = s.title.trim().isEmpty ? s.displayNameWOExt : s.title;
    final rawArtist = (s.artist == null ||
            s.artist!.trim().isEmpty ||
            s.artist == '<unknown>')
        ? unknownArtist
        : s.artist!;
    final shown = tidy
        ? TitleCleaner.clean(rawTitle, rawArtist)
        : (title: rawTitle, artist: rawArtist);
    return Track(
      id: s.id,
      title: shown.title,
      artist: shown.artist,
      rawTitle: rawTitle,
      rawArtist: rawArtist,
      album: (s.album == null || s.album == '<unknown>')
          ? 'Unknown album'
          : s.album!,
      path: s.data,
      duration: Duration(milliseconds: s.duration ?? 0),
      dateModified:
          DateTime.fromMillisecondsSinceEpoch((s.dateModified ?? 0) * 1000),
      fileExtension: s.fileExtension,
    );
  }

  String get durationLabel {
    final d = duration;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  }
}
