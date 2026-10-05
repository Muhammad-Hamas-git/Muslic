import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LibrarySort { artist, name, dateModified }

/// All user-tunable settings, persisted to SharedPreferences.
///
/// Library filters:
///  - [allowedFolders]: if non-empty, ONLY these folders (and subfolders) are scanned.
///  - [bannedFolders]: always excluded, wins over allowed.
///  - [minDurationSeconds] / [maxDurationSeconds]: length gate (0 = no limit).
///  - [includeSubfolders]: whether allow/ban rules apply recursively.
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;

  // ---- Library sourcing ----
  List<String> allowedFolders = [];
  List<String> bannedFolders = [];
  int minDurationSeconds = 0;
  int maxDurationSeconds = 0; // 0 = unlimited
  bool includeSubfolders = true;
  bool hideWhatsAppAudio = true; // common noise source, on by default

  // ---- Library view ----
  LibrarySort sort = LibrarySort.artist;
  bool sortAscending = true;
  bool tidyTitles = true; // shorten "Artist - Song (Official Video)" style names

  // ---- Playback ----
  bool resumeOnHeadphones = false;
  bool rememberPlaybackSettings = true; // persist speed/pitch/gain
  bool rememberLastSong = true; // resume last song and position on launch
  double lastSpeed = 1.0;
  double lastPitch = 1.0;
  double lastGainDb = 0.0;

  // ---- Equalizer ----
  bool eqEnabled = true;
  List<double> eqGains = []; // dB per band, applied once bands are known

  void _load() {
    allowedFolders = _prefs.getStringList('allowedFolders') ?? [];
    bannedFolders = _prefs.getStringList('bannedFolders') ?? [];
    minDurationSeconds = _prefs.getInt('minDurationSeconds') ?? 0;
    maxDurationSeconds = _prefs.getInt('maxDurationSeconds') ?? 0;
    includeSubfolders = _prefs.getBool('includeSubfolders') ?? true;
    hideWhatsAppAudio = _prefs.getBool('hideWhatsAppAudio') ?? true;
    // Stored by name under a new key, so the new artist default applies
    // to everyone once; older saved sorts are ignored.
    sort = LibrarySort.values.asNameMap()[_prefs.getString('sortBy')] ??
        LibrarySort.artist;
    sortAscending = _prefs.getBool('sortAscendingV2') ?? true;
    tidyTitles = _prefs.getBool('tidyTitles') ?? true;
    resumeOnHeadphones = _prefs.getBool('resumeOnHeadphones') ?? false;
    rememberPlaybackSettings =
        _prefs.getBool('rememberPlaybackSettings') ?? true;
    rememberLastSong = _prefs.getBool('rememberLastSong') ?? true;
    lastSpeed = (_prefs.getDouble('lastSpeed') ?? 1.0).clamp(0.5, 2.0);
    lastPitch = (_prefs.getDouble('lastPitch') ?? 1.0).clamp(0.5, 2.0);
    lastGainDb = _prefs.getDouble('lastGainDb') ?? 0.0;
    eqEnabled = _prefs.getBool('eqEnabled') ?? true;
    eqGains = (_prefs.getStringList('eqGains') ?? [])
        .map((e) => double.tryParse(e) ?? 0.0)
        .toList();
  }

  Future<void> _save() async {
    await _prefs.setStringList('allowedFolders', allowedFolders);
    await _prefs.setStringList('bannedFolders', bannedFolders);
    await _prefs.setInt('minDurationSeconds', minDurationSeconds);
    await _prefs.setInt('maxDurationSeconds', maxDurationSeconds);
    await _prefs.setBool('includeSubfolders', includeSubfolders);
    await _prefs.setBool('hideWhatsAppAudio', hideWhatsAppAudio);
    await _prefs.setString('sortBy', sort.name);
    await _prefs.setBool('sortAscendingV2', sortAscending);
    await _prefs.setBool('tidyTitles', tidyTitles);
    await _prefs.setBool('resumeOnHeadphones', resumeOnHeadphones);
    await _prefs.setBool(
        'rememberPlaybackSettings', rememberPlaybackSettings);
    await _prefs.setBool('rememberLastSong', rememberLastSong);
    await _prefs.setDouble('lastSpeed', lastSpeed);
    await _prefs.setDouble('lastPitch', lastPitch);
    await _prefs.setDouble('lastGainDb', lastGainDb);
    await _prefs.setBool('eqEnabled', eqEnabled);
    await _prefs.setStringList(
        'eqGains', [for (final g in eqGains) g.toStringAsFixed(2)]);
  }

  // ---- Mutators (each persists and notifies) ----

  void addAllowedFolder(String path) {
    final p = _norm(path);
    if (!allowedFolders.contains(p)) allowedFolders.add(p);
    _commit();
  }

  void removeAllowedFolder(String path) {
    allowedFolders.remove(path);
    _commit();
  }

  void addBannedFolder(String path) {
    final p = _norm(path);
    if (!bannedFolders.contains(p)) bannedFolders.add(p);
    _commit();
  }

  void removeBannedFolder(String path) {
    bannedFolders.remove(path);
    _commit();
  }

  void setMinDuration(int seconds) {
    minDurationSeconds = seconds.clamp(0, 36000);
    _commit();
  }

  void setMaxDuration(int seconds) {
    maxDurationSeconds = seconds.clamp(0, 360000);
    _commit();
  }

  void setIncludeSubfolders(bool v) {
    includeSubfolders = v;
    _commit();
  }

  void setHideWhatsAppAudio(bool v) {
    hideWhatsAppAudio = v;
    _commit();
  }

  void setSort(LibrarySort s, {bool? ascending}) {
    sort = s;
    if (ascending != null) sortAscending = ascending;
    _commit();
  }

  void setTidyTitles(bool v) {
    tidyTitles = v;
    _commit();
  }

  void toggleSortDirection() {
    sortAscending = !sortAscending;
    _commit();
  }

  void setRememberPlaybackSettings(bool v) {
    rememberPlaybackSettings = v;
    _commit();
  }

  void savePlaybackParams(
      {required double speed, required double pitch, required double gainDb}) {
    lastSpeed = speed;
    lastPitch = pitch;
    lastGainDb = gainDb;
    _save(); // no notify needed, purely persistence
  }

  void saveEqualizer({required bool enabled, required List<double> gains}) {
    eqEnabled = enabled;
    eqGains = List.of(gains);
    _save();
  }

  void setRememberLastSong(bool v) {
    rememberLastSong = v;
    if (!v) {
      _prefs.remove('sessionQueue');
      _prefs.remove('sessionTrack');
      _prefs.remove('sessionPositionMs');
    }
    _commit();
  }

  // ---- Last session (written often, so saved directly, no notify) ----

  void saveSessionQueue(List<int> ids) =>
      _prefs.setStringList('sessionQueue', [for (final i in ids) '$i']);

  void saveSessionPosition({required int trackId, required Duration position}) {
    _prefs.setInt('sessionTrack', trackId);
    _prefs.setInt('sessionPositionMs', position.inMilliseconds);
  }

  ({List<int> queueIds, int trackId, Duration position})? get lastSession {
    final track = _prefs.getInt('sessionTrack');
    if (track == null) return null;
    final ids = [
      for (final s in _prefs.getStringList('sessionQueue') ?? const <String>[])
        if (int.tryParse(s) case final int i) i
    ];
    return (
      queueIds: ids,
      trackId: track,
      position: Duration(milliseconds: _prefs.getInt('sessionPositionMs') ?? 0),
    );
  }

  void _commit() {
    _save();
    notifyListeners();
  }

  static String _norm(String p) =>
      p.endsWith('/') ? p.substring(0, p.length - 1) : p;
}
