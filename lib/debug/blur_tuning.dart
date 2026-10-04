import 'package:flutter/painting.dart';

/// Blur settings for the album-art backgrounds behind the mini player and
/// the full player.
///
/// HOW IT WORKS
/// When the library is scanned, every track's artwork is fetched once,
/// shrunk, blurred and saved to disk as a small JPEG. At runtime the app
/// only displays these finished files (scaled up, which keeps them smooth),
/// so nothing is blurred while you scroll or play.
///
/// HOW TO TUNE
/// Change the values below and rebuild. The cache key is built from the
/// "baked" values (marked [baked]), so changing any of them makes the app
/// regenerate every blurred image automatically on the next launch.
/// Display values (marked [live]) apply instantly with no regeneration.
class BlurTuning {
  BlurTuning._();

  // ---------------------------------------------------------------------
  // Baked into the cached files
  // ---------------------------------------------------------------------

  /// [baked] Size in px of the artwork requested from Android's media store.
  /// Larger costs more time per track and gains little, since it gets
  /// shrunk to [workingSize] anyway.
  static const int sourceSize = 300;

  /// [baked] The artwork is cropped square and shrunk to this many px
  /// before blurring. Smaller = softer look and faster processing.
  /// The final image is this size; it is scaled up on screen.
  static const int workingSize = 128;

  /// [baked] Gaussian blur radius, in px of [workingSize].
  /// Rough guide at workingSize 128: 4 = light, 10 = Figma's look, 20 = mush.
  /// Effective strength is about blurRadius / workingSize, so if you change
  /// workingSize, scale this with it.
  static const int blurRadius = 10;

  /// [baked] How many times the blur is applied. Each extra pass makes the
  /// result smoother and wider, like a larger radius but without banding.
  static const int blurPasses = 2;

  /// [baked] Colour saturation after blurring. 1.0 = unchanged.
  /// Blurring tends to look dull, so a small boost (1.1 to 1.3) helps.
  static const double saturation = 1.2;

  /// [baked] Brightness multiplier after blurring. 1.0 = unchanged.
  static const double brightness = 1.0;

  /// [baked] JPEG quality of the cached file (1 to 100).
  static const int jpegQuality = 92;

  // ---------------------------------------------------------------------
  // Applied at display time
  // ---------------------------------------------------------------------

  /// [live] Zoom of the blurred image inside the mini player.
  /// 1.0 = image just covers the bar. Above 1 crops in further, hiding the
  /// soft edges the blur leaves at the image border.
  static const double collapsedZoom = 1.05;

  /// [live] Zoom of the blurred image inside the full player card.
  /// Figma uses roughly 1.1 (a 2028 px image behind a 1848 px card).
  static const double expandedZoom = 1.10;

  /// [live] Black overlay on top of the blur to keep white text readable.
  /// 0.0 = none, 1.0 = solid black.
  static const double collapsedDarken = 0.08;
  static const double expandedDarken = 0.04;

  /// [live] Cross-fade when the song (and so the background) changes.
  static const Duration crossfade = Duration(milliseconds: 450);

  /// [live] Shown when a track has no artwork, or while its blur is being
  /// generated for the first time.
  static const Color fallbackTop = Color(0xFF6E7C66);
  static const Color fallbackBottom = Color(0xFF39452F);

  // ---------------------------------------------------------------------
  // Processing
  // ---------------------------------------------------------------------

  /// How many tracks are blurred in parallel after a library scan.
  /// 2 keeps the phone responsive; 3 or 4 finishes sooner on fast phones.
  static const int workers = 2;

  /// Cache key for the baked values. Do not edit by hand.
  static String get signature =>
      'b1-$sourceSize-$workingSize-$blurRadius-$blurPasses-'
      '$saturation-$brightness-$jpegQuality';
}
