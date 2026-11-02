import 'package:flutter/widgets.dart';

import '../ui/design.dart';

/// Maps Figma px on the 1080 x 2340 Terminal frames to screen points.
/// Things near the top follow the status bar; things near the bottom
/// (player bar, TV) are measured from the bottom edge, like the other
/// themes.
class TerminalLayout {
  TerminalLayout(BuildContext context)
      : f = Fg.of(context),
        pad = MediaQuery.paddingOf(context),
        size = MediaQuery.sizeOf(context);

  final Fg f;
  final EdgeInsets pad;
  final Size size;

  /// Screen y for a Figma y near the top (the Figma status bar is 40 px).
  double top(double y) => pad.top + f(y - 40);

  /// Screen y for a Figma y near the bottom.
  double bottom(double y) => size.height - pad.bottom - f(2340 - y);

  double x(double v) => f(v);

  /// Player bar (Figma 37, 2109, 1006 x 176).
  Rect get bar => Rect.fromLTWH(f(37), bottom(2109), f(1006), f(176));

  /// TV fully open (Figma 27, 1323, 1026 x 786).
  Rect get tvOpen => Rect.fromLTWH(f(27), bottom(1323), f(1026), f(786));

  /// Room for the horizontal carousel: between the artist name and the TV.
  double get roomTop => top(560);
  double get roomBottom => bottom(1323);
}
