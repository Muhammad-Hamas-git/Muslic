import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/library_screen.dart';
import 'services/artwork_cache.dart';
import 'state/library_controller.dart';
import 'state/player_controller.dart';
import 'state/settings_controller.dart';
import 'ui/design.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Media session + notification shade player + lock screen controls.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'app.muslic.playback',
    androidNotificationChannelName: 'müslic playback',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
    preloadArtwork: true,
  );

  // White app with dark status bar icons, drawn edge to edge.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  final results = await Future.wait([
    SharedPreferences.getInstance(),
    ArtworkCache.open(),
  ]);
  runApp(MuslicApp(
    prefs: results[0] as SharedPreferences,
    artwork: results[1] as ArtworkCache,
  ));
}

class MuslicApp extends StatelessWidget {
  const MuslicApp({super.key, required this.prefs, required this.artwork});
  final SharedPreferences prefs;
  final ArtworkCache artwork;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: artwork),
        ChangeNotifierProvider(create: (_) => SettingsController(prefs)),
        ChangeNotifierProvider(
          create: (c) =>
              LibraryController(c.read<SettingsController>(), artwork),
        ),
        ChangeNotifierProvider(
          create: (c) =>
              PlayerController(c.read<SettingsController>(), artwork),
        ),
      ],
      child: MaterialApp(
        title: 'müslic',
        debugShowCheckedModeBanner: false,
        theme: _theme(),
        home: const LibraryScreen(),
      ),
    );
  }

  /// Light theme matching the Figma file: white pages, near-black ink,
  /// Inter throughout. Used by the settings screen and dialogs; the
  /// library and player draw their own Figma styling.
  ThemeData _theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: Palette.ink,
      brightness: Brightness.light,
      surface: Colors.white,
    ).copyWith(primary: Palette.ink, secondary: Palette.blue);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: Colors.white,
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Color(0xFFF4F4F2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      chipTheme: const ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }
}
