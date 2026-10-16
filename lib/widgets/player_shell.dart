import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';

import '../debug/ambient_tuning.dart';
import '../debug/blur_tuning.dart';
import '../debug/ui_tuning.dart';
import '../models/track.dart';
import '../state/player_controller.dart';
import '../ui/design.dart';
import '../ui/skin.dart';
import 'ambient_stars.dart';
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
    with TickerProviderStateMixin {
  late final AnimationController _eq =
      AnimationController(vsync: this, duration: PlayerMotion.equalizer);

  /// 0 = square album art, 1 = CD (ambient on). Tuning: [CdTuning].
  late final AnimationController _cd =
      AnimationController(vsync: this, duration: CdTuning.morph);

  /// Horizontal offset of the art while it is swiped, in px.
  late final AnimationController _swipe =
      AnimationController.unbounded(vsync: this);

  /// Disc rotation in radians, kept within -pi..pi.
  final ValueNotifier<double> _angle = ValueNotifier(0);
  late final Ticker _spin = createTicker(_onSpin);
  Duration? _lastTick;
  double _spinSpeed = 0; // rad/s
  double? _uprightFrom; // angle when ambient turned off
  double _uprightT = 0;
  bool? _ambientOn;
  bool _playingNow = false;

  AnimationController get _x => widget.expansion;

  @override
  void dispose() {
    _spin.dispose();
    _eq.dispose();
    _cd.dispose();
    _swipe.dispose();
    _angle.dispose();
    super.dispose();
  }

  /// Keeps the CD morph and the spin in step with ambient mode.
  void _syncAmbient(bool ambient, bool playing) {
    _playingNow = playing;
    if (_ambientOn == ambient) return;
    if (_ambientOn == null) {
      _cd.value = ambient ? 1 : 0;
    } else {
      ambient
          ? _cd.animateTo(1, curve: Curves.easeInOutCubic)
          : _cd.animateTo(0, curve: Curves.easeInOutCubic);
    }
    _ambientOn = ambient;
    _uprightFrom = null;
    if (!_spin.isActive && (ambient || _angle.value != 0)) {
      _lastTick = null;
      _spin.start();
    }
  }

  void _onSpin(Duration elapsed) {
    final dt = _lastTick == null
        ? 0.0
        : (elapsed - _lastTick!).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final ramp = CdTuning.spinRamp.inMilliseconds / 1000;

    if (_ambientOn == true) {
      final spin = !CdTuning.spinOnlyWhilePlaying || _playingNow;
      final target = spin
          ? 2 * math.pi / (CdTuning.spinPeriod.inMilliseconds / 1000)
          : 0.0;
      // Ease the speed towards the target (reaches ~95% after `ramp`).
      _spinSpeed += (target - _spinSpeed) * (1 - math.exp(-dt * 3 / ramp));
      var a = _angle.value + _spinSpeed * dt;
      if (a > math.pi) a -= 2 * math.pi;
      _angle.value = a;
      return;
    }

    // Ambient off: turn back upright the short way, then stop.
    _spinSpeed = 0;
    _uprightFrom ??= _angle.value;
    _uprightT = (_uprightT + dt / ramp).clamp(0.0, 1.0);
    _angle.value =
        _uprightFrom! * (1 - Curves.easeInOutCubic.transform(_uprightT));
    if (_uprightT >= 1) {
      _angle.value = 0;
      _uprightFrom = null;
      _uprightT = 0;
      _spin.stop();
    }
  }

  bool get _canSwipe => _x.value >= 0.999 && _eq.value <= 0.001;

  void _swipeUpdate(DragUpdateDetails d) {
    if (!_canSwipe) return;
    final player = context.read<PlayerController>();
    final delta = d.primaryDelta ?? 0;
    final next = _swipe.value + delta;
    final blocked = (next < 0 && !player.hasNextTrack) ||
        (next > 0 && !player.hasPreviousTrack);
    // Nothing to go to on that side: the art only gives a little.
    _swipe.value = blocked ? _swipe.value + delta * 0.25 : next;
  }

  Future<void> _swipeEnd(DragEndDetails d, double width) async {
    final player = context.read<PlayerController>();
    final v = d.primaryVelocity ?? 0;
    final dx = _swipe.value;
    double dir = 0; // -1 = next (swiped left), 1 = previous
    if (v.abs() > ArtSwipeTuning.flingVelocity) {
      dir = v.sign;
    } else if (dx.abs() > width * ArtSwipeTuning.distance) {
      dir = dx.sign;
    }
    if (dir != 0 && dx != 0 && dir != dx.sign) dir = 0;
    final ok = dir < 0
        ? player.hasNextTrack
        : dir > 0
            ? player.hasPreviousTrack
            : false;
    if (!ok) {
      _swipe.animateTo(0,
          duration: ArtSwipeTuning.back, curve: Curves.easeOutBack);
      return;
    }
    await _swipe.animateTo(dir * width,
        duration: ArtSwipeTuning.out, curve: Curves.easeIn);
    await (dir < 0 ? player.next() : player.previousTrack());
    if (!mounted) return;
    _swipe.value = -dir * width;
    await _swipe.animateTo(0,
        duration: ArtSwipeTuning.back, curve: Curves.easeOutCubic);
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
    _syncAmbient(player.ambient, player.playing);

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

      return AnimatedBuilder(
        animation: Listenable.merge([_x, _eq, _cd, _swipe]),
        builder: (context, _) {
          final t = _x.value;
          final e = Curves.easeInOut.transform(_eq.value);
          final card = Rect.lerp(collapsed, expanded, t)!;
          final layout = _ExpandedLayout(f, expanded.size, e);

          // Album art flies from the bar into the card centre.
          final artFrom = Rect.fromLTWH(f(45), f(40), f(106), f(106))
              .shift(collapsed.topLeft);
          final artTo = layout.art.shift(expanded.topLeft);
          final art = Rect.lerp(artFrom, artTo, t)!.shift(-card.topLeft);

          // IMPORTANT: content is faded with paint alpha (the `fade`
          // values), never with an Opacity widget around blend images.
          // Opacity renders its child into a separate layer where the
          // screen blend has no background to blend with, so the glass
          // buttons would turn black mid-animation.
          final collapsedFade = (1 - t / 0.4).clamp(0.0, 1.0);
          final expandedFade = ((t - 0.4) / 0.6).clamp(0.0, 1.0);

          // CD look (ambient): only in the open player, so the mini bar
          // keeps a square cover.
          final cd = Curves.easeInOut.transform(_cd.value) * t;
          final shrink = 1 - 0.06 * e; // art shrinks as the EQ opens
          Rect scaled(Rect r) => Rect.fromCenter(
              center: art.center + (r.center - art.center) * shrink,
              width: r.width * shrink,
              height: r.height * shrink);
          final caseSide = art.width * CdTuning.caseScale;
          final caseRect = Rect.fromCenter(
              center: art.center, width: caseSide, height: caseSide);
          final discSide = caseSide * CdTuning.discSize;
          final discFull = Rect.fromCenter(
              center: caseRect.topLeft +
                  Offset(CdTuning.discCentreX * caseSide,
                      CdTuning.discCentreY * caseSide),
              width: discSide,
              height: discSide);
          final swipe = _swipe.value;
          final disc =
              scaled(Rect.lerp(art, discFull, cd)!).shift(Offset(swipe, 0));
          final swipeFade =
              (1 - swipe.abs() / expanded.width * 0.7).clamp(0.0, 1.0);
          final artFade = (1 - e) * swipeFade;
          final caseFade = cd * (1 - e) * CdTuning.caseOpacity;

          return PopScope(
            canPop: t == 0,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              _eq.value > 0 ? _eq.reverse() : _close();
            },
            // Every child below stays in the tree (or has a key) for the
            // whole animation. Adding the backdrop only once the card
            // started moving used to shift the card to a new slot in this
            // Stack mid-drag, which rebuilt its GestureDetector and dropped
            // the drag: the "stuck" player when dragged up by hand.
            child: Stack(
              children: [
                // Page behind the open card (with the ambient stars);
                // blocks the library.
                Positioned.fill(
                  key: const ValueKey('backdrop'),
                  child: IgnorePointer(
                    ignoring: t < 0.05,
                    child: t <= 0
                        ? const SizedBox.shrink()
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              ColoredBox(
                                  color: Skin.of(context)
                                      .background
                                      .withValues(alpha: t)),
                              AmbientStars(opacity: t),
                            ],
                          ),
                  ),
                ),
                Positioned.fromRect(
                  key: const ValueKey('card'),
                  rect: card,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_x.value < 0.01) _open();
                    },
                    onVerticalDragStart: (_) => _x.stop(),
                    onVerticalDragUpdate: (d) =>
                        _x.value -= (d.primaryDelta ?? 0) / travel,
                    onVerticalDragEnd: (d) =>
                        _settle(d.primaryVelocity ?? 0, travel),
                    onVerticalDragCancel: () => _settle(0, travel),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(f(85)),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            key: const ValueKey('blur'),
                            child: BlurredArt(
                              track: track,
                              zoom: lerpDouble(BlurTuning.collapsedZoom,
                                  BlurTuning.expandedZoom, t)!,
                              // Theme dimming (dark: half brightness) stacks
                              // with the readability darkening.
                              darken: 1 -
                                  (1 -
                                          lerpDouble(
                                              BlurTuning.collapsedDarken,
                                              BlurTuning.expandedDarken,
                                              t)!) *
                                      (1 - Skin.of(context).blurDim),
                            ),
                          ),
                          if (collapsedFade > 0)
                            Positioned(
                              key: const ValueKey('collapsed'),
                              left: 0,
                              top: 0,
                              width: collapsed.width,
                              height: collapsed.height,
                              child: IgnorePointer(
                                ignoring: t > 0.2,
                                child: _CollapsedContent(
                                  player: player,
                                  track: track,
                                  fade: collapsedFade,
                                ),
                              ),
                            ),
                          if (expandedFade > 0)
                            Positioned(
                              key: const ValueKey('expanded'),
                              left: 0,
                              top: 0,
                              width: expanded.width,
                              height: expanded.height,
                              child: IgnorePointer(
                                ignoring: t < 0.8,
                                child: _ExpandedContent(
                                  player: player,
                                  track: track,
                                  layout: layout,
                                  eq: e,
                                  fade: expandedFade,
                                  onMinimize: _close,
                                  onEqualizer: _toggleEq,
                                ),
                              ),
                            ),
                          if (artFade > 0)
                            Positioned.fromRect(
                              key: const ValueKey('art'),
                              rect: disc,
                              child: IgnorePointer(
                                child: _plainFade(
                                  artFade,
                                  _Art(
                                    track: track,
                                    radius: lerpDouble(f(25), 0, t)!,
                                    shadow: 1 - t,
                                    cd: cd,
                                    angle: _angle,
                                    f: f,
                                  ),
                                ),
                              ),
                            ),
                          // CD case over the disc, screen blended (paint
                          // alpha only, see above).
                          if (caseFade > 0)
                            Positioned.fromRect(
                              key: const ValueKey('case'),
                              rect: scaled(caseRect),
                              child: IgnorePointer(
                                child: BlendImage(UiAssets.cdCase,
                                    opacity: caseFade),
                              ),
                            ),
                          // Swipe the art left/right to change song.
                          if (t >= 0.999 && e <= 0.001)
                            Positioned.fromRect(
                              key: const ValueKey('swipe'),
                              rect: art,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onHorizontalDragStart: (_) => _swipe.stop(),
                                onHorizontalDragUpdate: _swipeUpdate,
                                onHorizontalDragEnd: (d) =>
                                    _swipeEnd(d, expanded.width),
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
/// at 36, 256). [eq] (0 to 1) is how far the equalizer is open: the control
/// panel slides down into the space below it and the equalizer panel grows
/// to fill the room it leaves.
class _ExpandedLayout {
  /// How far the control panel slides down when the equalizer opens, in
  /// Figma px. Figma leaves 224 px under the panel; this keeps 50 of them.
  static const double eqPanelDrop = 174;

  factory _ExpandedLayout(Fg f, Size card, double eq) {
    final restTop = card.height - f(224 + 458);
    final panel =
        Rect.fromLTWH(f(120), restTop + f(eqPanelDrop) * eq, f(787), f(458));

    // The art sits centred between the top buttons and the control panel,
    // with equal gaps above and below. It is Figma's 773 px when there is
    // room, and shrinks only if the gaps would drop below [minGap].
    const buttonsBottom = 163.0; // bottom of minimize/EQ/ambient (Figma)
    const minGap = 40.0;
    final room = restTop - f(buttonsBottom);
    final side = (room - 2 * f(minGap)).clamp(f(300), f(773)).toDouble();
    final gap = (room - side) / 2;
    final art = Rect.fromLTWH(
        (card.width - side) / 2, f(buttonsBottom) + gap, side, side);

    return _ExpandedLayout._(
      minimize: Rect.fromLTWH(f(120), f(67), f(96), f(96)),
      eqButton: Rect.fromLTWH(f(759), f(56), f(162), f(107)),
      // Same image canvas as the EQ button, one glass circle (97 px) plus a
      // 28 px gap to its left.
      ambientButton: Rect.fromLTWH(f(759 - 125), f(56), f(162), f(107)),
      panel: panel,
      art: art,
      eqPanel: Rect.fromLTRB(panel.left, f(190), panel.right, panel.top - f(30)),
    );
  }

  const _ExpandedLayout._({
    required this.minimize,
    required this.eqButton,
    required this.ambientButton,
    required this.panel,
    required this.art,
    required this.eqPanel,
  });

  final Rect minimize;
  final Rect eqButton;
  final Rect ambientButton;
  final Rect panel;
  final Rect art;
  final Rect eqPanel;
}

/// The album art. [cd] (0..1) morphs it from a square into a CD: round,
/// with a hole in the middle, turning by [angle].
class _Art extends StatelessWidget {
  const _Art({
    required this.track,
    required this.radius,
    required this.shadow,
    required this.cd,
    required this.angle,
    required this.f,
  });

  final Track track;
  final double radius;
  final double shadow;
  final double cd;
  final ValueListenable<double> angle;
  final Fg f;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final side = c.biggest.shortestSide;
      final corner = lerpDouble(radius, side / 2, cd)!;
      final hole = side * CdTuning.holeSize / 2 * cd;
      final image = TrackArt(track: track, decodeWidth: 900);

      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(corner),
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
        // Its own layer, so the turning disc repaints alone each frame.
        child: RepaintBoundary(
          child: ClipPath(
            clipper: _DiscClipper(corner: corner, hole: hole),
            child: cd <= 0
                ? image
                : AnimatedBuilder(
                    animation: angle,
                    builder: (context, child) => Transform.rotate(
                        angle: angle.value * cd, child: child),
                    child: image,
                  ),
          ),
        ),
      );
    });
  }
}

/// A rounded square (a circle when [corner] is half the side) with a round
/// hole of radius [hole] in the middle.
class _DiscClipper extends CustomClipper<Path> {
  const _DiscClipper({required this.corner, required this.hole});
  final double corner;
  final double hole;

  @override
  Path getClip(Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, Radius.circular(corner)));
    if (hole > 0.5) {
      path.addOval(
          Rect.fromCircle(center: size.center(Offset.zero), radius: hole));
    }
    return path;
  }

  @override
  bool shouldReclip(_DiscClipper old) =>
      old.corner != corner || old.hole != hole;
}

/// Wraps plain (non-blended) content in an Opacity. Safe for text and
/// normal images; do not put [BlendImage]/[GlassButton] with screen
/// blending inside it.
Widget _plainFade(double fade, Widget child) =>
    fade >= 1 ? child : Opacity(opacity: fade, child: child);

class _CollapsedContent extends StatelessWidget {
  const _CollapsedContent(
      {required this.player, required this.track, required this.fade});

  final PlayerController player;
  final Track track;
  final double fade;

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    return Stack(
      children: [
        Positioned(
          left: f(188),
          top: f(58),
          width: f(396),
          child: _plainFade(
            fade,
            Text(track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Txt.inter(f(36), FontWeight.w500)),
          ),
        ),
        Positioned(
          left: f(188),
          top: f(110),
          width: f(396),
          child: _plainFade(
            fade,
            Text(track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Txt.inter(f(24), FontWeight.w400)),
          ),
        ),
        Positioned(
          left: f(604),
          top: f(46),
          child: GlassButton(
            asset: UiAssets.prev,
            width: f(93),
            height: f(93),
            opacity: fade,
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
            opacity: fade,
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
            opacity: fade,
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
    required this.fade,
    required this.onMinimize,
    required this.onEqualizer,
  });

  final PlayerController player;
  final Track track;
  final _ExpandedLayout layout;
  final double eq; // 0 = art showing, 1 = equalizer open
  final double fade; // overall fade-in while the player expands
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
            opacity: fade,
            onTap: onMinimize,
            semanticLabel: 'Minimize player',
          ),
        ),
        Positioned.fromRect(
          rect: layout.ambientButton,
          child: GlassButton(
            asset: player.ambient ? UiAssets.ambientOn : UiAssets.ambient,
            width: layout.ambientButton.width,
            height: layout.ambientButton.height,
            opacity: fade,
            onTap: () => player.setAmbient(!player.ambient),
            semanticLabel: player.ambient ? 'Ambient on' : 'Ambient off',
          ),
        ),
        Positioned.fromRect(
          rect: layout.eqButton,
          child: GlassButton(
            asset: UiAssets.equalizer,
            width: layout.eqButton.width,
            height: layout.eqButton.height,
            opacity: fade,
            onTap: onEqualizer,
            semanticLabel: 'Equalizer',
          ),
        ),

        // Equalizer, in place of the album art.
        if (eq > 0)
          Positioned.fromRect(
            rect: layout.eqPanel,
            child: EqualizerPanel(fade: eq * fade),
          ),

        // Control panel.
        Positioned.fromRect(
            rect: p, child: BlendImage(UiAssets.panel, opacity: fade)),
        Positioned(
          left: p.left + f(40),
          width: p.width - f(80),
          top: p.top + f(101),
          height: f(60),
          child: _plainFade(fade, _Title(text: track.title)),
        ),
        Positioned(
          left: p.left + f(40),
          width: p.width - f(80),
          top: p.top + f(166),
          child: _plainFade(
            fade,
            Text(track.artist,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Txt.inter(f(32), FontWeight.w400)),
          ),
        ),
        // Shuffle and loop are drawn bigger than Figma for easier tapping,
        // centred on their Figma positions (ButtonTuning.loopShuffleScale).
        at(
          87 - 27 * ButtonTuning.loopShuffleScale,
          302.5 - 22.5 * ButtonTuning.loopShuffleScale,
          GlassButton(
            asset: UiAssets.shuffle,
            blendMode: BlendMode.srcOver,
            opacity: (player.shuffle ? 1.0 : 0.45) * fade,
            width: f(54 * ButtonTuning.loopShuffleScale),
            height: f(45 * ButtonTuning.loopShuffleScale),
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
            opacity: fade,
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
            opacity: fade,
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
            opacity: fade,
            onTap: player.next,
            semanticLabel: 'Next',
          ),
        ),
        at(
          681.5 - 22.5 * ButtonTuning.loopShuffleScale,
          296.5 - 22.5 * ButtonTuning.loopShuffleScale,
          _LoopButton(player: player, fade: fade),
        ),
        Positioned(
          left: p.left + f(60) - f(15),
          top: p.top + f(391) - f(10),
          width: f(644) + f(30),
          height: f(50),
          child: _plainFade(fade, _Seekbar(player: player)),
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
  const _LoopButton({required this.player, required this.fade});
  final PlayerController player;
  final double fade;

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
          opacity: (mode == LoopMode.off ? 0.45 : 1.0) * fade,
          width: f(45 * ButtonTuning.loopShuffleScale),
          height: f(45 * ButtonTuning.loopShuffleScale),
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
              child: _plainFade(
                  fade, Text('1', style: Txt.inter(f(22), FontWeight.w700))),
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
