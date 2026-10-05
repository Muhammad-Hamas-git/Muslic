import 'package:flutter_test/flutter_test.dart';
import 'package:muslic/services/title_cleaner.dart';

void main() {
  void check(String title, String artist, String wantTitle, String wantArtist) {
    final r = TitleCleaner.clean(title, artist);
    expect((r.title, r.artist), (wantTitle, wantArtist),
        reason: '"$title" by "$artist"');
  }

  test('artist in title replaces any artist tag', () {
    check('Novo Amor - Emigrate (Official Music Video)', 'NOVOAMORFAN2000',
        'Emigrate', 'Novo Amor');
    check('Novo Amor - Emigrate (Official Music Video)', 'Unknown artist',
        'Emigrate', 'Novo Amor');
    check('Daft Punk - One More Time (Official Video) [4K]', 'DaftPunkVEVO',
        'One More Time', 'Daft Punk');
    check('Artist – Song [HD] (Lyrics)', 'x', 'Song', 'Artist');
  });

  test('brackets removed, artist kept when title has no dash', () {
    check('Paint It Gold (Paint It Gold)', 'Glen Check', 'Paint It Gold',
        'Glen Check');
    check('Song (feat. X) - Live at Wembley - 2011 Remaster', 'Band', 'Song',
        'Band');
  });

  test('release notes after a dash are dropped, not used as titles', () {
    check('Here Comes the Sun - Remastered 2009', 'The Beatles',
        'Here Comes the Sun', 'The Beatles');
  });

  test('track numbers are dropped', () {
    check('07 - Emigrate', 'Novo Amor', 'Emigrate', 'Novo Amor');
  });

  test('unspaced hyphens and all-bracket titles are left alone', () {
    check('Jay-Z Song', 'Jay-Z', 'Jay-Z Song', 'Jay-Z');
    check('(Intro)', 'Band', '(Intro)', 'Band');
  });
}
