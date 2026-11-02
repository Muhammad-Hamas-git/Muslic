import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../debug/terminal_tuning.dart';
import '../models/track.dart';
import '../ui/design.dart';
import '../widgets/blend_image.dart';
import '../widgets/crt.dart';
import 'terminal_carousel.dart';
import 'terminal_layout.dart';
import 'terminal_player.dart';

/// The whole Terminal theme screen: a CRT "screen" layer (green gradient,
/// carousel, titles, logo and icons) with the player bar and TV on top of
/// it. [expansion] 0..1 is how far the TV is pulled out.
class TerminalView extends StatelessWidget {
  const TerminalView({
    super.key,
    required this.expansion,
    required this.tracks,
    required this.onSelect,
    required this.onSettings,
    required this.onSearch,
    required this.searchIcon,
    this.onSongPassed,
    this.focusTrackId,
    this.status,
    this.hasPlayer = true,
  });

  final AnimationController expansion;
  final List<Track> tracks;
  final void Function(int index) onSelect;
  final VoidCallback onSettings;
  final VoidCallback onSearch;
  final VoidCallback? onSongPassed;
  final int? focusTrackId;

  /// Shown instead of the carousel (scanning, no songs, ...).
  final Widget? status;

  /// Search icon, or the close glyph while searching.
  final Widget searchIcon;

  final bool hasPlayer;

  @override
  Widget build(BuildContext context) {
    final l = TerminalLayout(context);
    final f = l.f;

    final screen = Stack(
      children: [
        // Black to green, ending half way down in the library and at the
        // bottom with the TV out.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: expansion,
            builder: (context, _) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, TerminalTuning.gradientBottom],
                  stops: [
                    0,
                    lerpDouble(TerminalTuning.gradientEndLibrary,
                        TerminalTuning.gradientEndPlayer, expansion.value)!,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: status ??
              TerminalCarousel(
                tracks: tracks,
                expansion: expansion,
                onSelect: onSelect,
                onSongPassed: onSongPassed,
                focusTrackId: focusTrackId,
              ),
        ),
        Positioned(
          left: f(397),
          top: l.top(55),
          width: f(285),
          height: f(119),
          child: Image.asset(UiAssets.termLogo, fit: BoxFit.contain),
        ),
        Positioned(
          left: f(60),
          top: l.top(79),
          width: f(72),
          height: f(72),
          child: Bouncy(
            onTap: onSettings,
            semanticLabel: 'Settings',
            child: Image.asset(UiAssets.termSettings,
                filterQuality: FilterQuality.none),
          ),
        ),
        Positioned(
          left: f(948),
          top: l.top(79),
          width: f(72),
          height: f(72),
          child: searchIcon,
        ),
      ],
    );

    return Stack(
      children: [
        // The screen behind glass. The player and TV sit on top of the
        // glass, so they are outside the effect.
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black,
            child: CrtFilter(
              params: TerminalTuning.screen,
              fallbackScanlines: true,
              child: screen,
            ),
          ),
        ),
        if (hasPlayer)
          Positioned.fill(child: TerminalPlayer(expansion: expansion)),
      ],
    );
  }
}
