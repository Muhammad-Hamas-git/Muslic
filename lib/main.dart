import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/library_screen.dart';
import 'state/library_controller.dart';
import 'state/player_controller.dart';
import 'state/settings_controller.dart';

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

  final prefs = await SharedPreferences.getInstance();
  runApp(MuslicApp(prefs: prefs));
}

class MuslicApp extends StatelessWidget {
  const MuslicApp({super.key, required this.prefs});
  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsController(prefs)),
        ChangeNotifierProvider(
          create: (c) => LibraryController(c.read<SettingsController>()),
        ),
        ChangeNotifierProvider(
          create: (c) => PlayerController(c.read<SettingsController>()),
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

  /// müslic wears "toasted oat": deep roasted-brown surfaces with a warm
  /// honey-gold accent. Deliberately not another purple Material app.
  ThemeData _theme() {
    const honey = Color(0xFFE8A94C);
    const roast = Color(0xFF171210);

    final scheme = ColorScheme.fromSeed(
      seedColor: honey,
      brightness: Brightness.dark,
      surface: roast,
    ).copyWith(
      primary: honey,
      surfaceContainer: const Color(0xFF221B17),
      surfaceContainerHigh: const Color(0xFF2A211C),
      surfaceContainerHighest: const Color(0xFF332822),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: roast,
      fontFamilyFallback: const ['Roboto'],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: honey,
        thumbColor: honey,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
        trackHeight: 3.5,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
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
