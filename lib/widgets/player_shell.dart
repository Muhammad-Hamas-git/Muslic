import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';

import '../debug/blur_tuning.dart';
import '../debug/ui_tuning.dart';
import '../models/track.dart';
import '../state/player_controller.dart';
import '../ui/design.dart';
import 'art.dart';
import 'blend_image.dart';
import 'equalizer_panel.dart';
import 'glass_slider.dart';
import 'muslic_app_bar.dart';

/// The player in both states. Collapsed it is the Figma "Collapsed Player"
/// bar at the bottom; tapping or swiping it up grows the same card into the
/// full "Player Screen" card, with the album art flying from the bar into
/// the centre. Both states sit on the pre-blurred album art of the current
/// song.
///
/// [expansion] runs 0 (collapsed) to 1 (expanded). The library screen owns
/// it so it can fade its own icons and open the player from the carousel.
class PlayerShell extends StatefulWidget {
  const PlayerShell({super.key, required this.expansion});

  final AnimationController expansion;

  static void open(AnimationController c) =>
      c.animateTo(1, curve: Curves.easeOutCubic);
  static void close(AnimationController c) =>
      c.animateTo(0, curve: Curves.easeOutCubic);

  @override
  State<PlayerShell> createState() => _PlayerShellState();
}

class _PlayerShellState extends State<PlayerShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _eq =
      AnimationController(vsync: this, duration: PlayerMotion.equalizer);

  AnimationController get _x => widget.expansion;

  @override
  void dispose() {
    _eq.dispose();
    super.dispose();
  }

  void _open() => PlayerShell.open(_x);

  void _close() {
    _eq.reverse();
    PlayerShell.close(_x);
  }

  void _toggleEq() => _eq.isDismissed || _eq.status == AnimationStatus.reverse
      ? _eq.forward()
      : _eq.reverse();

  void _settle(double velocity, double travel) {
    if (velocity.abs() > PlayerMotion.flingVelocity) {
      velocity < 0 ? _open() : _close();
    } else {
      _x.value > 0.5 ? _open() : _close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final track = player.current;
    if (track == null) return const SizedBox.shrink();

    final f = Fg.of(context);
    final pad = MediaQuery.paddingOf(context);
    final appBarBottom = MuslicAppBar.bottom(context);

    return LayoutBuilder(builder: (context, c) {
      final h = c.maxHeight;
      // Card rects in both states (Figma: bar 1007 x 186 at 54 px from the
      // bottom; full card 1007 wide, 82 px below the app bar, 236 px above
      // the bottom).
      final collapsed = Rect.fromLTWH(
          f(36), h - pad.bottom - f(54 + 186), f(1007), f(186));
      final expanded = Rect.fromLTRB(
          f(36), appBarBottom + f(82), f(1043), h - pad.bottom - f(236));
      final travel = collapsed.top - expanded.top;
      final layout = _ExpandedLayout(f, expanded.size);

      return AnimatedBuilder(
        animation: Listenable.merge([_x, _eq]),
        builder: (context, _) {
          final t = _x.value;
          final e = Curves.easeInOut.transform(_eq.value);
          final card = Rect.lerp(collapsed, expanded, t)!;

          // Album art flies from the bar into the card centre.
          final artFrom = Rect.fromLTWH(f(45), f(40), f(106), f(106))
              .shift(collapsed.topLeft);
          final artTo = layout.art.shift(expanded.topLeft);
          final art = Rect.lerp(artFrom, artTo, t)!.shift(-card.topLeft);

          return PopScope(
            canPop: t == 0,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              _eq.value > 0 ? _eq.reverse() : _close();
            },
            child: Stack(
              children: [
                // White page behind the open card; blocks the library.
                if (t > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: t < 0.05,
                      child: ColoredBox(
                          color: Colors.white.withValues(alpha: t)),
                    ),
                  ),
                Positioned.fromRect(
                  rect: card,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: t < 0.01 ? _open : null,
                    onVerticalDragUpdate: (d) =>
                        _x.value -= (d.primaryDelta ?? 0) / travel,
                    onVerticalDragEnd: (d) =>
                        _settle(d.primaryVelocity ?? 0, travel),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(f(85)),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: BlurredArt(
                              track: track,
                              zoom: lerpDouble(BlurTuning.collapsedZoom,
                                  BlurTuning.expandedZoom, t)!,
                              darken: lerpDouble(BlurTuning.collapsedDarken,
                                  BlurTuning.expandedDarken, t)!,
                            ),
                          ),
                          if (t < 0.4)
                            Positioned(
                              left: 0,
                              top: 0,
                              width: collapsed.width,
                              height: collapsed.height,
                              child: Opacity(
                                opacity: (1 - t / 0.4).clamp(0.0, 1.0),
                                child: _CollapsedContent(
                                    player: player, track: track),
                              ),
                            ),
                          if (t > 0.4)
                            Positioned(
                              left: 0,
                              top: 0,
                              width: expanded.width,
                              height: expanded.height,
                              child: Opacity(
                                opacity: ((t - 0.4) / 0.6).clamp(0.0, 1.0),
                                child: _ExpandedContent(
                                  player: player,
                                  track: track,
                                  layout: layout,
                                  eq: e,
                                  onMinimize: _close,
                                  onEqualizer: _toggleEq,
                                ),
                              ),
                            ),
                          if (e < 1)
                            Positioned.fromRect(
                              rect: art,
                              child: Opacity(
                                opacity: 1 - e,
                                child: Transform.scale(
                                  scale: 1 - 0.06 * e,
                                  child: _Art(
                                    track: track,
                                    radius: lerpDouble(f(25), 0, t)!,
                                    shadow: 1 - t,
                                    f: f,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }
}

/// Positions inside the full card, from Figma's Player Screen (card origin
/// at 36, 256). The control panel keeps Figma's distance from the card
/// bottom; the album art shrinks if a short phone leaves too little room.
class _ExpandedLayout {
  _ExpandedLayout(Fg f, Size card)
      : minimize = Rect.fromLTWH(f(120), f(67), f(96), f(96)),
        eqButton = Rect.fromLTWH(f(759), f(56), f(162), f(107)),
        panel = Rect.fromLTWH(
            f(120), card.height - f(224 + 458), f(787), f(458)),
        art = Rect.zero,
        eqPanel = Rect.zero {
    // Figma: art 773 px, 118 px above the panel, top at 274. On shorter
    // phones the space above the art shrinks first (down to just below the
    // top buttons), then the gap to the panel, and only then the art.
    const minTop = 190.0, minGap = 60.0;
    final side = (panel.top - f(minTop + minGap)).clamp(f(300), f(773)).toDouble();
    final gap = (panel.top - f(minTop) - side).clamp(f(minGap), f(118)).toDouble();
    final artTop = panel.top - gap - side;
    art = Rect.fromLTWH((card.width - side) / 2, artTop, side, side);
    eqPanel = Rect.fromLTRB(
        panel.left, f(193), panel.right, panel.top - f(30));
  }

  final Rect minimize;
  final Rect eqButton;
  final Rect panel;
  Rect art;
  Rect eqPanel;
}

class _Art extends StatelessWidget {
  const _Art(
      {required this.track,
      required this.radius,
      required this.shadow,
      required this.f});

  final Track track;
  final double radius;
  final double shadow;
  final Fg f;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow <= 0
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25 * shadow),
                  offset: Offset(0, f(4)),
                  blurRadius: f(75),
                  spreadRadius: f(25) * shadow,
                ),
              ],
      ),
      child: TrackArt(track: track, decodeWidth: 900, radius: radius),
    );
  }
}

class _CollapsedContent extends StatelessWidget {
  const _CollapsedContent({required this.player, required this.track});

  final PlayerController player;
  final Track track;

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    return Stack(
      children: [
        Positioned(
          left: f(188),
          top: f(58),
          width: f(396),
          child: Text(track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Txt.inter(f(36), FontWeight.w500)),
        ),
        Positioned(
          left: f(188),
          top: f(110),
          width: f(396),
          child: Text(track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Txt.inter(f(24), FontWeight.w400)),
        ),
        Positioned(
          left: f(604),
          top: f(46),
          child: GlassButton(
            asset: UiAssets.prev,
            width: f(93),
            height: f(93),
            onTap: player.previous,
            semanticLabel: 'Previous',
          ),
        ),
        Positioned(
          left: f(722),
          top: f(29),
          child: GlassButton(
            asset: player.playing ? UiAssets.pause : UiAssets.play,
            width: f(127),
            height: f(127),
            onTap: player.togglePlay,
            semanticLabel: player.playing ? 'Pause' : 'Play',
          ),
        ),
        Positioned(
          left: f(874),
          top: f(46),
          child: GlassButton(
            asset: UiAssets.next,
            width: f(93),
            height: f(93),
            onTap: player.next,
            semanticLabel: 'Next',
          ),
        ),
      ],
    );
  }
}

class _ExpandedContent extends StatelessWidget {
  const _ExpandedContent({
    required this.player,
    required this.track,
    required this.layout,
    required this.eq,
    required this.onMinimize,
    required this.onEqualizer,
  });

  final PlayerController player;
  final Track track;
  final _ExpandedLayout layout;
  final double eq; // 0 = art showing, 1 = equalizer open
  final VoidCallback onMinimize;
  final VoidCallback onEqualizer;

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    final p = layout.panel;

    Widget at(double x, double y, Widget child) =>
        Positioned(left: p.left + f(x), top: p.top + f(y), child: child);

    return Stack(
      children: [
        Positioned.fromRect(
          rect: layout.minimize,
          child: GlassButton(
            asset: UiAssets.minimize,
            width: layout.minimize.width,
            height: layout.minimize.height,
            onTap: onMinimize,
            semanticLabel: 'Minimize player',
          ),
        ),
        Positioned.fromRect(
          rect: layout.eqButton,
          child: GlassButton(
            asset: UiAssets.equalizer,
            width: layout.eqButton.width,
            height: layout.eqButton.height,
            onTap: onEqualizer,
            semanticLabel: 'Equalizer',
          ),
        ),

        // Equalizer, in place of the album art.
        if (eq > 0)
          Positioned.fromRect(
            rect: layout.eqPanel,
            child: Opacity(
              opacity: eq,
              child: Transform.scale(
                scale: 0.94 + 0.06 * eq,
                child: const EqualizerPanel(),
              ),
            ),
          ),

        // Control panel.
        Positioned.fromRect(rect: p, child: const BlendImage(UiAssets.panel)),
        Positioned(
          left: p.left + f(40),
          width: p.width - f(80),
          top: p.top + f(101),
          height: f(60),
          child: _Title(text: track.title),
        ),
        Positioned(
          left: p.left + f(40),
          width: p.width - f(80),
          top: p.top + f(166),
          child: Text(track.artist,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Txt.inter(f(32), FontWeight.w400)),
        ),
        at(
          60,
          280,
          GlassButton(
            asset: UiAssets.shuffle,
            blendMode: BlendMode.srcOver,
            opacity: player.shuffle ? 1.0 : 0.45,
            width: f(54),
            height: f(45),
            onTap: player.toggleShuffle,
            semanticLabel: player.shuffle ? 'Shuffle on' : 'Shuffle off',
          ),
        ),
        at(
          204,
          258,
          GlassButton(
            asset: UiAssets.prev,
            width: f(90),
            height: f(90),
            onTap: player.previous,
            semanticLabel: 'Previous',
          ),
        ),
        at(
          324,
          240,
          GlassButton(
            asset: player.playing ? UiAssets.pause : UiAssets.play,
            width: f(125),
            height: f(125),
            onTap: player.togglePlay,
            semanticLabel: player.playing ? 'Pause' : 'Play',
          ),
        ),
        at(
          479,
          258,
          GlassButton(
            asset: UiAssets.next,
            width: f(90),
            height: f(90),
            onTap: player.next,
            semanticLabel: 'Next',
          ),
        ),
        at(659, 274, _LoopButton(player: player)),
        Positioned(
          left: p.left + f(60) - f(15),
          top: p.top + f(391) - f(10),
          width: f(644) + f(30),
          height: f(50),
          child: _Seekbar(player: player),
        ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    final style = Txt.inter(f(48), FontWeight.w700);
    return LayoutBuilder(builder: (context, c) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      if (painter.width <= c.maxWidth) {
        return Text(text, textAlign: TextAlign.center, style: style);
      }
      return Marquee(
        key: ValueKey(text),
        text: text,
        style: style,
        blankSpace: f(120),
        velocity: 30,
        pauseAfterRound: const Duration(seconds: 2),
        fadingEdgeStartFraction: 0.08,
        fadingEdgeEndFraction: 0.08,
      );
    });
  }
}

class _LoopButton extends StatelessWidget {
  const _LoopButton({required this.player});
  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    final mode = player.loopMode;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GlassButton(
          asset: UiAssets.loop,
          blendMode: BlendMode.srcOver,
          opacity: mode == LoopMode.off ? 0.45 : 1.0,
          width: f(45),
          height: f(45),
          onTap: player.cycleLoopMode,
          semanticLabel: switch (mode) {
            LoopMode.off => 'Repeat off',
            LoopMode.all => 'Repeat all',
            LoopMode.one => 'Repeat one',
          },
        ),
        if (mode == LoopMode.one)
          Positioned(
            right: -f(12),
            top: -f(14),
            child: IgnorePointer(
              child: Text('1', style: Txt.inter(f(22), FontWeight.w700)),
            ),
          ),
      ],
    );
  }
}

class _Seekbar extends StatelessWidget {
  const _Seekbar({required this.player});
  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snap) {
        final total = player.duration.inMilliseconds.toDouble();
        final pos = (snap.data ?? Duration.zero).inMilliseconds.toDouble();
        return GlassSlider(
          value: total <= 0 ? 0 : pos.clamp(0, total),
          min: 0,
          max: total <= 0 ? 1 : total,
          onChanged: (_) {},
          onChangeEnd: (v) => player.seek(Duration(milliseconds: v.round())),
        );
      },
    );
  }
}
