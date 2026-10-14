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
import 'ui/skin.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Media session + notification shade player + lock screen controls.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.dotstudios.muslic.playback',
    androidNotificationChannelName: 'Playback',
    androidNotificationChannelDescription:
        'Player controls in the notification shade and on the lock screen',
    // White "mü" silhouette (android/app/src/main/res/drawable-*/).
    androidNotificationIcon: 'drawable/ic_stat_muslic',
    notificationColor: const Color(0xFF111111),
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
    preloadArtwork: true,
  );

  // Drawn edge to edge; status bar icon colours follow the theme (see
  // the AnnotatedRegion in MuslicApp).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

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
      child: Builder(builder: (context) {
        final skin = Skin.of(context);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: skin.systemBars,
          child: MaterialApp(
            title: 'müslic',
            debugShowCheckedModeBanner: false,
            theme: _theme(Brightness.light),
            darkTheme: _theme(Brightness.dark),
            themeMode: skin.dark ? ThemeMode.dark : ThemeMode.light,
            builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
              value: skin.systemBars,
              child: child!,
            ),
            home: const LibraryScreen(),
          ),
        );
      }),
    );
  }

  /// Material theme for the settings screen and dialogs (the library and
  /// player draw their own Figma styling). Light: white pages, near-black
  /// ink. Dark: pure black pages, white ink. Inter throughout.
  ThemeData _theme(Brightness b) {
    final dark = b == Brightness.dark;
    final ink = dark ? Colors.white : Palette.ink;
    final page = dark ? Colors.black : Colors.white;
    final scheme = ColorScheme.fromSeed(
      seedColor: Palette.ink,
      brightness: b,
      surface: page,
    ).copyWith(
      primary: ink,
      onPrimary: page,
      secondary: Palette.blue,
      surface: page,
      onSurface: ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: page,
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? const Color(0xFF151517) : const Color(0xFFF4F4F2),
        shape: const RoundedRectangleBorder(
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
