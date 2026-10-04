/// Layout and motion values for the carousel and player animation.
/// All sizes are in Figma px (the design frame is 1080 px wide); the app
/// scales them to the phone's width.
class CarouselTuning {
  CarouselTuning._();

  /// Item size, vertical offset from the centre, and white wash, by
  /// distance from the centred item (0 = centre, 1 = neighbour, ...).
  /// Values in between are interpolated, which is what makes the scroll
  /// feel continuous. Index 0..3 here = distance 0..3.
  static const List<double> size = [670, 520, 414, 330];
  static const List<double> offset = [0, 437, 693, 900];
  static const List<double> whiteWash = [0, 0.30, 0.50, 0.80];

  /// Right edge of every item, in Figma px from the left.
  static const double rightEdge = 1020;

  /// Scroll distance (Figma px) that moves the carousel by one song.
  /// Lower = faster scrolling per swipe.
  static const double scrollStep = 437;

  /// Where the centred item sits between the app bar (0.0) and the mini
  /// player (1.0). Figma puts it at about 0.49.
  static const double centerFraction = 0.49;

  /// Time the carousel takes to glide to a song you tapped.
  static const Duration tapScroll = Duration(milliseconds: 380);
}

class PlayerMotion {
  PlayerMotion._();

  /// Mini player to full player (and back).
  static const Duration expand = Duration(milliseconds: 460);

  /// Velocity (px per second) above which a swipe on the player always
  /// finishes the open or close, regardless of how far it was dragged.
  static const double flingVelocity = 700;

  /// Equalizer panel open/close inside the player.
  static const Duration equalizer = Duration(milliseconds: 320);
}
