# müslic

A warm, fast, local-only Android music player built with Flutter. Plays MP3, M4A/AAC, WAV, FLAC, OGG and anything else Android's ExoPlayer decodes.

## Features

- **Library grid** of every audio file on the device: album art, title, artist, and length badge. Switch between list, 2-column and 3-column layouts. Sort by name or date updated, ascending or descending. Instant search across title, artist and album.
- **Player**: full-screen sheet with centered album art, marquee title, seek bar, shuffle, repeat (off / all / one), previous/next. Swipe it down to tab it away; playback continues and a docked mini player stays on the library screen.
- **Playback lab** (advanced controls): speed 0.25x–3x and pitch 0.5x–2x, independently (time-stretching via Sonic under the hood, so speed changes do not chipmunk the audio unless you also move pitch). Boost up to +12 dB via Android's LoudnessEnhancer, whose internal limiter compresses peaks instead of hard-clipping. Preset chips for common values, one-tap reset, and the settings persist across launches if you want them to.
- **Settings**: allow-list folders (scan only these), ban-list folders (never scan these), recursive or exact folder matching, minimum and maximum track length gates, a WhatsApp voice-note filter, and library rescan. The folder picker offers the folders that actually contain audio plus a full system browser.
- **Background play** with a media-style notification in the shade and on the lock screen (art, title, transport controls), headset button support, and audio-focus handling (ducks/pauses for calls and other apps).
- **Robustness**: unreadable or corrupt files are skipped automatically instead of killing the queue; permission denial, empty library, and over-filtered library each get a clear recovery screen.

## Project layout

```
lib/
  main.dart                     # init just_audio_background, theme, providers
  models/track.dart             # Track model from MediaStore rows
  state/settings_controller.dart# persisted user settings
  state/library_controller.dart # permissions, scan, filter, sort
  state/player_controller.dart  # queue, speed/pitch/gain, error recovery
  screens/library_screen.dart   # grid + sort menu + search + states
  screens/player_screen.dart    # full player + playback lab sheet
  screens/settings_screen.dart  # sources, length gates, playback prefs
  widgets/artwork.dart          # cached album art with fallback
  widgets/mini_player.dart      # docked persistent player
```

## Build without installing anything (GitHub Actions)

1. Create a GitHub repository and push this folder to it (including the hidden `.github` folder).
2. Open the repo's **Actions** tab. The "Build müslic APK" workflow runs on every push, or start it manually with **Run workflow**.
3. After about 5 to 8 minutes, open the finished run and download `muslic-release-apk` under Artifacts. Unzip it and install `app-release.apk` on your phone (allow installs from unknown sources).

The release APK is signed with Flutter's debug key, which is fine for installing on your own phone but not for the Play Store.

## Build locally

1. Install Flutter (3.19+) with the Android toolchain.
2. `flutter create .` inside this folder to generate the platform scaffolding (this repo ships only the Dart sources, manifest and pubspec).
3. Replace the generated `android/app/src/main/AndroidManifest.xml` with the one in this repo (it registers the media session service, the media button receiver and all permissions, and swaps `MainActivity` for `AudioServiceActivity` as just_audio_background requires).
4. Apply `android/app/build.gradle.snippet` to the generated Gradle file: `minSdk 23`, your `applicationId`.
5. `flutter pub get`
6. `flutter run` (or `flutter build apk --release`).

On first launch the app requests `READ_MEDIA_AUDIO` (Android 13+) or `READ_EXTERNAL_STORAGE` (12 and below) plus notification permission for the shade player.

## Performance notes

- The library scan is a single MediaStore query, not a filesystem crawl; filtering and sorting happen in memory and re-run only when a setting changes.
- Grid tiles render artwork through `QueryArtworkWidget` with `keepOldArtwork` so scrolling never flashes placeholders, and slivers keep offscreen tiles unbuilt.
- The queue is a single `ConcatenatingAudioSource`, so next/previous is gapless and lock-screen skipping is instant.

## Tuning it yourself

- Speed/pitch/boost ranges: clamps in `player_controller.dart` (`setSpeed`, `setPitch`, `setGainDb`).
- Grid aspect ratio and columns: `library_screen.dart`, the `SliverGridDelegateWithFixedCrossAxisCount`.
- Theme colors: `_theme()` in `main.dart` (`honey`, `roast`).
- Duration preset chips: `settings_screen.dart` (`presets` lists).
