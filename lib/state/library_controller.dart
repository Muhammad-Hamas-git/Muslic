import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/track.dart';
import '../services/artwork_cache.dart';
import 'settings_controller.dart';

enum LibraryStatus { idle, noPermission, scanning, ready, empty, error }

/// Owns the scanned library and applies the user's filters and sort.
class LibraryController extends ChangeNotifier {
  LibraryController(this._settings, this._art) {
    _settings.addListener(_onSettingsChanged);
  }

  final SettingsController _settings;
  final ArtworkCache _art;
  final OnAudioQuery _query = OnAudioQuery();

  LibraryStatus status = LibraryStatus.idle;
  String? errorMessage;

  List<SongModel> _songs = [];
  bool? _tidyApplied;
  List<Track> _all = [];
  List<Track> tracks = [];
  String searchTerm = '';

  /// Every scanned song by id (ignores filters and search).
  Map<int, Track> get byId => {for (final t in _all) t.id: t};

  /// Distinct folders found on device (for the settings folder pickers).
  List<String> get discoveredFolders {
    final set = <String>{for (final t in _all) t.folder};
    final list = set.toList()..sort();
    return list;
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (_tidyApplied != null && _tidyApplied != _settings.tidyTitles) {
      _buildTracks();
    }
    _applyFilters();
  }

  void _buildTracks() {
    _tidyApplied = _settings.tidyTitles;
    _all = [
      for (final s in _songs) Track.fromSong(s, tidy: _settings.tidyTitles)
    ];
  }

  Future<bool> _ensurePermission() async {
    // Android 13+ uses READ_MEDIA_AUDIO; older uses storage.
    final audio = await Permission.audio.request();
    if (audio.isGranted) return true;
    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  Future<void> scan() async {
    status = LibraryStatus.scanning;
    errorMessage = null;
    notifyListeners();

    try {
      if (!await _ensurePermission()) {
        status = LibraryStatus.noPermission;
        notifyListeners();
        return;
      }
      // Android 13+ hides the media notification (and so the lock screen
      // and notification shade player) unless this is granted. Asked once;
      // playback works either way.
      await Permission.notification.request();

      final songs = await _query.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
      );

      _songs = songs
          .where((s) => (s.isMusic ?? true) || (s.isAudioBook ?? false))
          .toList();
      _buildTracks();

      _applyFilters();
      // Pre-blur backgrounds for what is visible first, then the rest.
      _art.warm(tracks);
      _art.warm(_all);
    } catch (e) {
      status = LibraryStatus.error;
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  void setSearch(String term) {
    searchTerm = term;
    _applyFilters();
  }

  bool _folderMatches(String trackFolder, String rule) {
    if (trackFolder == rule) return true;
    if (_settings.includeSubfolders && trackFolder.startsWith('$rule/')) {
      return true;
    }
    return false;
  }

  void _applyFilters() {
    final allowed = _settings.allowedFolders;
    final banned = _settings.bannedFolders;
    final minMs = _settings.minDurationSeconds * 1000;
    final maxMs = _settings.maxDurationSeconds * 1000;
    final q = searchTerm.toLowerCase().trim();

    var list = _all.where((t) {
      if (t.duration.inMilliseconds < minMs) return false;
      if (maxMs > 0 && t.duration.inMilliseconds > maxMs) return false;
      if (_settings.hideWhatsAppAudio &&
          t.path.contains('/WhatsApp/Media/')) {
        return false;
      }
      if (banned.any((b) => _folderMatches(t.folder, b))) return false;
      if (allowed.isNotEmpty &&
          !allowed.any((a) => _folderMatches(t.folder, a))) {
        return false;
      }
      if (q.isNotEmpty &&
          !t.title.toLowerCase().contains(q) &&
          !t.artist.toLowerCase().contains(q) &&
          !t.album.toLowerCase().contains(q) &&
          !t.rawTitle.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();

    int byText(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
    int byArtist(Track a, Track b) {
      // "Unknown artist" goes after everything else.
      final ua = a.artist == Track.unknownArtist, ub = b.artist == Track.unknownArtist;
      if (ua != ub) return ua ? 1 : -1;
      final c = byText(a.artist, b.artist);
      return c != 0 ? c : byText(a.title, b.title);
    }

    switch (_settings.sort) {
      case LibrarySort.artist:
        list.sort(byArtist);
      case LibrarySort.name:
        list.sort((a, b) => byText(a.title, b.title));
      case LibrarySort.dateModified:
        // Newest first when "ascending" (the default direction).
        list.sort((a, b) => b.dateModified.compareTo(a.dateModified));
    }
    if (!_settings.sortAscending) {
      list = list.reversed.toList();
    }

    tracks = list;
    if (status != LibraryStatus.noPermission &&
        status != LibraryStatus.error) {
      status = _all.isEmpty ? LibraryStatus.empty : LibraryStatus.ready;
    }
    notifyListeners();
  }
}
