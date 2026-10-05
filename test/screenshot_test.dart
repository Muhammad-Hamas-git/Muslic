// Renders the main screens with made-up songs and generated cover art and
// saves them as PNGs (test/screenshots/), so the UI can be checked against
// the Figma file without a phone. Run with:
//   flutter test --update-goldens test/screenshot_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:just_audio/just_audio.dart';
import 'package:muslic/models/track.dart';
import 'package:muslic/screens/library_screen.dart';
import 'package:muslic/services/artwork_cache.dart';
import 'package:muslic/state/library_controller.dart';
import 'package:muslic/state/player_controller.dart';
import 'package:muslic/state/settings_controller.dart';
import 'package:muslic/widgets/equalizer_panel.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _tracks = [
  for (final (i, title, artist) in [
    (0, 'Hollow Fields', 'Mira Vance'),
    (1, 'Paper Lanterns', 'The Quiet Hours'),
    (2, 'Look Up Slowly', 'Oren Hale'),
    (3, 'Glass Harbor', 'Juno Park'),
    (4, 'Night Bus', 'Sable & Finch'),
    (5, 'Low Tide', 'Mira Vance'),
    (6, 'Static Bloom', 'Ilse Moreau'),
  ])
    Track(
      id: 100 + i,
      title: title,
      artist: artist,
      album: 'Album $i',
      path: '/music/$i.mp3',
      duration: Duration(minutes: 3, seconds: 10 * i),
      dateModified: DateTime(2026, 1, 1 + i),
    ),
];

/// Abstract generated covers: a two-colour gradient with a few circles.
Uint8List _cover(int seed) {
  final palettes = [
    [0xFF4E7A3A, 0xFFB9D99A], // green field
    [0xFF1E5AA8, 0xFF7FD3F0], // pool blue
    [0xFFB08A5C, 0xFF5E7FA8], // sand + sky
    [0xFF2B2B2B, 0xFFE8E2D4], // monochrome
    [0xFF8E2C48, 0xFFF2A65A], // sunset
    [0xFF3D2C8D, 0xFF9C6BE0],
    [0xFF0F4C4C, 0xFFE0C36B],
  ];
  final p = palettes[seed % palettes.length];
  final c0 = img.ColorRgb8((p[0] >> 16) & 255, (p[0] >> 8) & 255, p[0] & 255);
  final c1 = img.ColorRgb8((p[1] >> 16) & 255, (p[1] >> 8) & 255, p[1] & 255);
  const n = 400;
  final im = img.Image(width: n, height: n);
  for (var y = 0; y < n; y++) {
    final t = y / n;
    final r = (c0.r + (c1.r - c0.r) * t).round();
    final g = (c0.g + (c1.g - c0.g) * t).round();
    final b = (c0.b + (c1.b - c0.b) * t).round();
    img.drawLine(im,
        x1: 0, y1: y, x2: n - 1, y2: y, color: img.ColorRgb8(r, g, b));
  }
  final rnd = math.Random(seed);
  for (var k = 0; k < 5; k++) {
    img.fillCircle(im,
        x: rnd.nextInt(n),
        y: rnd.nextInt(n),
        radius: 20 + rnd.nextInt(70),
        color: img.ColorRgba8(255, 255, 255, 90));
  }
  return img.encodeJpg(im, quality: 92);
}

class FakeLibrary extends ChangeNotifier implements LibraryController {
  @override
  LibraryStatus status = LibraryStatus.ready;
  @override
  List<Track> tracks = _tracks;
  @override
  String searchTerm = '';
  @override
  String? errorMessage;
  @override
  Future<void> scan() async {}
  @override
  void setSearch(String term) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakePlayer extends ChangeNotifier implements PlayerController {
  @override
  Track? current = _tracks[2];
  @override
  bool get playing => true;
  @override
  LoopMode get loopMode => LoopMode.all;
  @override
  bool get shuffle => false;
  @override
  Duration get duration => const Duration(minutes: 4);
  @override
  Stream<Duration> get positionStream =>
      Stream.value(const Duration(minutes: 2, seconds: 20));
  @override
  double speed = 1.2;
  @override
  double pitch = 1.0;
  @override
  double gainDb = 4.0;
  @override
  bool eqEnabled = true;
  @override
  List<double> eqFrequencies = [60, 230, 910, 3600, 14000];
  @override
  List<double> eqGains = [4, 2, 0, -2, 3];
  @override
  double eqMinDb = -15;
  @override
  double eqMaxDb = 15;
  @override
  bool get eqReady => true;
  @override
  Future<Track?> restoreSession(Map<int, Track> byId) async => null;
  @override
  void saveSession() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _loadFonts() async {
  Future<void> load(String family, String asset) async {
    final loader = FontLoader(family)..addFont(rootBundle.load(asset));
    await loader.load();
  }

  await load('Inter', 'assets/fonts/Inter.ttf');
  await load('KumbhSans', 'assets/fonts/KumbhSans.ttf');
  await load('MaterialIcons', 'fonts/MaterialIcons-Regular.otf')
      .catchError((_) {});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ArtworkCache cache;
  late Directory tmp;

  setUpAll(() async {
    await _loadFonts();
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final covers = {for (final t in _tracks) t.id: _cover(t.id)};
    messenger.setMockMethodCallHandler(
        const MethodChannel('com.lucasjosino.on_audio_query'), (call) async {
      if (call.method == 'queryArtwork') {
        return covers[(call.arguments as Map)['id']];
      }
      return null;
    });
    tmp = await Directory.systemTemp.createTemp('muslic_art');
  });

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    debugDisableShadows = false; // reset in shot()
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(top: 72, bottom: 48);
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      cache = await ArtworkCache.open(root: Directory('${tmp.path}/a'));
      for (final t in _tracks) {
        await cache.sharpFile(t);
      }
      cache.warm(_tracks);
      while (cache.pending.value > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider.value(value: cache),
        ChangeNotifierProvider(create: (_) => SettingsController(prefs)),
        ChangeNotifierProvider<LibraryController>(create: (_) => FakeLibrary()),
        ChangeNotifierProvider<PlayerController>(create: (_) => FakePlayer()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Inter'),
        home: home,
      ),
    ));
    // Let file images decode (real I/O), then settle frames.
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
    }
  }

  // flutter_test draws shadows unblurred by default; turn real shadows on
  // just for the capture (the framework expects the flag reset afterwards).
  Future<void> shot(WidgetTester tester, String name) async {
    try {
      await expectLater(
          find.byType(LibraryScreen), matchesGoldenFile('screenshots/$name.png'));
    } finally {
      debugDisableShadows = true;
    }
  }

  testWidgets('library with mini player', (tester) async {
    await pumpApp(tester, const LibraryScreen());
    await shot(tester, '1_library');
  });

  testWidgets('expanded player', (tester) async {
    await pumpApp(tester, const LibraryScreen());
    await tester.tapAt(const Offset(110, 700)); // mini player title area
    await settle(tester);
    await shot(tester, '2_player');
  });

  testWidgets('equalizer open', (tester) async {
    await pumpApp(tester, const LibraryScreen());
    await tester.tapAt(const Offset(110, 700));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Equalizer'));
    await settle(tester);
    expect(find.byType(EqualizerPanel), findsOneWidget);
    await shot(tester, '3_equalizer');
  });

  testWidgets('carousel scrolled by one song', (tester) async {
    await pumpApp(tester, const LibraryScreen());
    await tester.dragFrom(const Offset(250, 450), const Offset(0, -150));
    await settle(tester);
    await shot(tester, '4_library_scrolled');
  });

  testWidgets('player halfway through opening', (tester) async {
    await pumpApp(tester, const LibraryScreen());
    await tester.tapAt(const Offset(110, 700));
    await tester.pump(); // starts the animation clock
    await tester.pump(const Duration(milliseconds: 200));
    await shot(tester, '5_opening_halfway');
  });

  testWidgets('equalizer halfway through opening', (tester) async {
    await pumpApp(tester, const LibraryScreen());
    await tester.tapAt(const Offset(110, 700));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Equalizer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await shot(tester, '6_equalizer_halfway');
  });
}
