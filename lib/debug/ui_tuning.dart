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

/// Equalizer panel values.
class EqTuning {
  EqTuning._();

  /// The values the speed and pitch sliders snap to (ascending, must
  /// include 1.0). Add 2.0 here for a "double speed" stop.
  static const List<double> rateStops = [0.5, 0.8, 0.9, 1.0, 1.1, 1.2, 1.5];

  /// The values (dB) the boost slider snaps to (ascending, must include 0).
  static const List<double> boostStops = [0, 2, 4, 6, 8];

  /// Equalizer band slider knob radius and line thickness, in Figma px.
  static const double bandKnob = 26;
  static const double bandLine = 7;

  /// Speed/pitch/boost knob radius and line thickness, in Figma px.
  static const double rateKnob = 20;
  static const double rateLine = 6;
}
