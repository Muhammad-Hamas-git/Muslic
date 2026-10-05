/// Tidies song titles for display. The files themselves are never changed.
///
/// Rules, in order:
///  1. Remove anything in brackets: (), [], {} and 【】, including nested
///     ones. "Emigrate (Official Music Video) [HD]" -> "Emigrate".
///  2. Drop a trailing " - <tag>" when the tag is a release note such as
///     "Remastered 2011", "Live", "Radio Edit", "Official Video".
///  3. Drop a leading track number: "07 - Emigrate" -> "Emigrate".
///  4. If what is left is "<A> - <B>", treat A as the artist and B as the
///     title. The file's artist tag is replaced, whatever it said.
///     "Novo Amor - Emigrate" -> title "Emigrate", artist "Novo Amor".
///
/// Only a dash with spaces on both sides counts as a separator (-, – or —),
/// so names like "Jay-Z" or "Twenty-One" are left alone.
class TitleCleaner {
  TitleCleaner._();

  static final _bracketed =
      RegExp(r'\s*[\(\[\{【][^\(\)\[\]\{\}【】]*[\)\]\}】]');
  static final _unmatchedOpen = RegExp(r'\s*[\(\[\{【][^\)\]\}】]*$');
  static final _separator = RegExp(r'\s+[-–—]\s+');
  static final _spaces = RegExp(r'\s{2,}');
  static final _edgeJunk = RegExp(r'^[\s\-–—|:~_.,]+|[\s\-–—|:~_,]+$');
  static final _trackNumber = RegExp(r'^\d{1,3}\.?$');

  /// Words that mark the part after a dash as a release note, not a title.
  static final _releaseNote = RegExp(
    r'^(?:\d{4}\s+)?(?:re-?master(?:ed)?|live\b|remix|mix\b|edit\b|radio edit|'
    r'version|acoustic|demo\b|mono\b|stereo\b|instrumental|extended|single\b|'
    r'official|audio\b|video\b|lyric|visuali[sz]er|hd\b|hq\b|4k\b|explicit|clean\b)',
    caseSensitive: false,
  );

  static ({String title, String artist}) clean(String title, String artist) {
    var t = title;

    // 1. Brackets, repeated so nested brackets go too.
    String before;
    do {
      before = t;
      t = t.replaceAll(_bracketed, '');
    } while (t != before);
    t = t.replaceAll(_unmatchedOpen, '');
    t = _tidy(t);

    // 2. Trailing release note, possibly several: "Song - Live - Remastered".
    t = _dropReleaseNotes(t);

    var a = artist;
    final m = _separator.firstMatch(t);
    if (m != null) {
      final left = _tidy(t.substring(0, m.start));
      final right = _tidy(t.substring(m.end));
      if (left.isNotEmpty && right.isNotEmpty) {
        if (_trackNumber.hasMatch(left)) {
          // 3. "07 - Song"
          t = right;
        } else {
          // 4. "Artist - Song"
          a = left;
          t = right;
        }
        t = _dropReleaseNotes(t);
      }
    }

    if (t.isEmpty) t = title.trim();
    if (a.trim().isEmpty) a = artist;
    return (title: t, artist: a);
  }

  static String _tidy(String s) =>
      s.replaceAll(_spaces, ' ').replaceAll(_edgeJunk, '').trim();

  static String _dropReleaseNotes(String s) {
    while (true) {
      final matches = _separator.allMatches(s).toList();
      if (matches.isEmpty) return s;
      final last = matches.last;
      final tail = s.substring(last.end).trim();
      final head = s.substring(0, last.start).trim();
      if (head.isEmpty || !_releaseNote.hasMatch(tail)) return s;
      s = _tidy(head);
    }
  }
}
