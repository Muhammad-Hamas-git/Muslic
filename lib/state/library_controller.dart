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

  List<Track> _all = [];
  List<Track> tracks = [];
  String searchTerm = '';

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
    _applyFilters();
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

      final songs = await _query.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
      );

      _all = songs
          .where((s) => (s.isMusic ?? true) || (s.isAudioBook ?? false))
          .map(Track.fromSong)
          .toList();

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
          !t.album.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();

    switch (_settings.sort) {
      case LibrarySort.name:
        list.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case LibrarySort.dateModified:
        list.sort((a, b) => a.dateModified.compareTo(b.dateModified));
        break;
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
