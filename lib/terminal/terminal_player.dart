import 'dart:io';
import 'dart:ui' show FontFeature, lerpDouble;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';

import '../debug/terminal_tuning.dart';
import '../debug/ui_tuning.dart';
import '../models/track.dart';
import '../services/artwork_cache.dart';
import '../state/player_controller.dart';
import '../ui/design.dart';
import '../widgets/blend_image.dart';
import '../widgets/crt.dart';
import '../widgets/equalizer_panel.dart';
import 'mech_sound.dart';
import 'term_tint.dart';
import 'terminal_layout.dart';

/// The Terminal theme's player: the bar at the bottom and the TV that
/// slides up out of it. Tapping the bar (outside its buttons) or dragging
/// it up opens the TV; tapping the bar again, dragging the TV down or Back
/// closes it. Both sit above the screen's CRT effect, with their own dither
/// baked into the images (ci/make_terminal_assets.py); the album art and
/// texts inside their screens have their own CRT effects.
class TerminalPlayer extends StatefulWidget {
  const TerminalPlayer({super.key, required this.expansion});

  final AnimationController expansion;

  @override
  State<TerminalPlayer> createState() => _TerminalPlayerState();
}

class _TerminalPlayerState extends State<TerminalPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _eq =
      AnimationController(vsync: this, duration: PlayerMotion.equalizer);

  AnimationController get _x => widget.expansion;

  @override
  void dispose() {
    _eq.dispose();
    super.dispose();
  }

  void _open() => _x.animateTo(1,
      duration: TerminalTuning.open, curve: Curves.easeOutCubic);
  void _close() {
    _eq.reverse();
    _x.animateTo(0, duration: TerminalTuning.open, curve: Curves.easeOutCubic);
  }

  void _toggle() => _x.value > 0.5 ? _close() : _open();

  void _drag(DragUpdateDetails d, double travel) {
    _x.value -= (d.primaryDelta ?? 0) / travel;
  }

  void _settle(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() > PlayerMotion.flingVelocity) {
      v < 0 ? _open() : _close();
    } else {
      _x.value > 0.5 ? _open() : _close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final track = player.current;
    if (track == null) return const SizedBox.shrink();
    final l = TerminalLayout(context);
    final bar = l.bar;
    final tvOpen = l.tvOpen;
    final travel = bar.top - tvOpen.top;

    return AnimatedBuilder(
      animation: Listenable.merge([_x, _eq]),
      builder: (context, _) {
        final t = _x.value;
        final e = Curves.easeInOut.transform(_eq.value);
        final tvTop = lerpDouble(bar.top + l.f(40), tvOpen.top, t)!;
        return PopScope(
          canPop: t == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _eq.value > 0 ? _eq.reverse() : _close();
          },
          child: Stack(
            children: [
              // TV, sliding up from behind the bar; cut off below the bar's
              // middle so it never shows under it.
              Positioned(
                key: const ValueKey('tv'),
                left: 0,
                right: 0,
                top: 0,
                bottom: l.size.height - bar.center.dy,
                child: ClipRect(
                  child: Stack(
                    children: [
                      if (t > 0)
                        Positioned(
                          left: tvOpen.left,
                          top: tvTop,
                          width: tvOpen.width,
                          height: tvOpen.height,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragUpdate: (d) => _drag(d, travel),
                            onVerticalDragEnd: _settle,
                            child: _Tv(
                              player: player,
                              track: track,
                              eq: e,
                              onEqualizer: () => _eq.isDismissed ||
                                      _eq.status == AnimationStatus.reverse
                                  ? _eq.forward()
                                  : _eq.reverse(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned.fromRect(
                key: const ValueKey('bar'),
                rect: bar,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                  onVerticalDragUpdate: (d) => _drag(d, travel),
                  onVerticalDragEnd: _settle,
                  child: _Bar(player: player, track: track),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A dithered image button: crisp pixels, press bounce, optional green
/// "lit" tint when its mode is on.
class _PixelButton extends StatelessWidget {
  const _PixelButton({
    required this.asset,
    required this.onTap,
    required this.label,
    this.lit = false,
    this.badge,
  });

  final String asset;
  final VoidCallback onTap;
  final String label;
  final bool lit;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    Widget img = Image.asset(asset,
        fit: BoxFit.fill, filterQuality: FilterQuality.none);
    if (lit) {
      img = ColorFiltered(
        colorFilter: ColorFilter.mode(
            TerminalTuning.phosphor.withValues(alpha: 0.45), BlendMode.srcATop),
        child: img,
      );
    }
    return MechSound(
      child: Bouncy(
      onTap: onTap,
      semanticLabel: label,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          img,
          if (badge != null)
            Positioned(
              right: -f(4),
              top: -f(8),
              child: Text(badge!,
                  style: TextStyle(
                      fontFamily: 'FiraCode',
                      fontSize: f(20),
                      color: TerminalTuning.phosphor)),
            ),
        ],
      ),
    ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.player, required this.track});
  final PlayerController player;
  final Track track;

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    final cache = context.read<ArtworkCache>();
    Widget at(double x, double y, double w, double h, Widget child) =>
        Positioned(left: f(x), top: f(y), width: f(w), height: f(h), child: child);
    final loop = player.loopMode;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Image.asset(UiAssets.termBar,
              fit: BoxFit.fill, filterQuality: FilterQuality.none),
        ),
        at(84, 29, 550, 130, const ColoredBox(color: Colors.black)),
        at(
          86,
          41,
          106,
          106,
          ValueListenableBuilder<File?>(
            valueListenable: cache.sharp(track),
            builder: (context, file, _) =>
                CrtImage(file: file, params: TerminalTuning.miniArt),
          ),
        ),
        at(
          203,
          50,
          420,
          38,
          CrtFilter(
            params: TerminalTuning.miniTime,
            child: _TimeText(player: player),
          ),
        ),
        at(
          203,
          101,
          420,
          48,
          CrtFilter(
            params: TerminalTuning.miniTitle,
            // DSEG's space is narrow; '!' is its full-width blank.
            child: _LcdTitle(
                text: track.title.toUpperCase().replaceAll(' ', '!')),
          ),
        ),
        at(
          674,
          19,
          70,
          70,
          _PixelButton(
            asset: UiAssets.termLoop,
            label: switch (loop) {
              LoopMode.off => 'Repeat off',
              LoopMode.all => 'Repeat all',
              LoopMode.one => 'Repeat one',
            },
            lit: loop != LoopMode.off,
            badge: loop == LoopMode.one ? '1' : null,
            onTap: player.cycleLoopMode,
          ),
        ),
        at(
          674,
          103,
          70,
          70,
          _PixelButton(
            asset: UiAssets.termShuffle,
            label: player.shuffle ? 'Shuffle on' : 'Shuffle off',
            lit: player.shuffle,
            onTap: player.toggleShuffle,
          ),
        ),
        at(
          772,
          29,
          202,
          65,
          _PixelButton(
            asset: player.playing ? UiAssets.termPause : UiAssets.termPlay,
            label: player.playing ? 'Pause' : 'Play',
            onTap: player.togglePlay,
          ),
        ),
        at(772, 114, 91, 53,
            _PixelButton(
                asset: UiAssets.termPrev,
                label: 'Previous',
                onTap: player.previous)),
        at(883, 114, 91, 53,
            _PixelButton(
                asset: UiAssets.termNext, label: 'Next', onTap: player.next)),
      ],
    );
  }
}

class _TimeText extends StatelessWidget {
  const _TimeText({required this.player});
  final PlayerController player;

  static String fmt(Duration d) {
    final s = d.inSeconds;
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    final ss = sec.toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snap) {
        final total = player.duration;
        var pos = snap.data ?? Duration.zero;
        if (total > Duration.zero && pos > total) pos = total;
        return Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${fmt(pos)} / ${fmt(total)}',
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'FiraCode',
              fontSize: f(22),
              color: TerminalTuning.phosphor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
      },
    );
  }
}

/// Song title in the segment font; scrolls like an old LCD when too long.
class _LcdTitle extends StatelessWidget {
  const _LcdTitle({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    final style = TextStyle(
        fontFamily: 'DSEG14',
        fontSize: f(34),
        height: 1.2,
        color: TerminalTuning.phosphor);
    return LayoutBuilder(builder: (context, c) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      if (painter.width <= c.maxWidth) {
        return Align(
            alignment: Alignment.centerLeft,
            child: Text(text, maxLines: 1, style: style));
      }
      return Marquee(
        key: ValueKey(text),
        text: text,
        style: style,
        blankSpace: f(120),
        velocity: 28,
        pauseAfterRound: const Duration(seconds: 2),
      );
    });
  }
}

/// The TV: album art (or the equalizer) on its screen, a seek bar along
/// the bottom, and the equalizer and ambient buttons.
class _Tv extends StatelessWidget {
  const _Tv({
    required this.player,
    required this.track,
    required this.eq,
    required this.onEqualizer,
  });

  final PlayerController player;
  final Track track;
  final double eq; // 0 = art, 1 = equalizer on screen
  final VoidCallback onEqualizer;

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    final cache = context.read<ArtworkCache>();
    Widget at(double x, double y, double w, double h, Widget child) =>
        Positioned(left: f(x), top: f(y), width: f(w), height: f(h), child: child);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Image.asset(UiAssets.termTv,
              fit: BoxFit.fill, filterQuality: FilterQuality.none),
        ),
        // Screen: album art through the CRT, bulging to fit the glass.
        at(
          103,
          92,
          813,
          601,
          Stack(
            fit: StackFit.expand,
            children: [
              if (eq < 1)
                Opacity(
                  opacity: 1 - eq,
                  child: ValueListenableBuilder<File?>(
                    valueListenable: cache.sharp(track),
                    builder: (context, file, _) => CrtImage(
                        file: file,
                        params: TerminalTuning.tvArt,
                        decodeWidth: 900),
                  ),
                ),
              // Equalizer on the TV: black screen, green controls, behind
              // the same CRT glass (gentler settings, so text stays sharp).
              if (eq > 0)
                Opacity(
                  opacity: eq,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(f(40)),
                    child: ColoredBox(
                      color: Colors.black,
                      child: CrtFilter(
                        params: TerminalTuning.tvEqualizer,
                        child: ColorFiltered(
                          colorFilter: TermTint.mono(),
                          child: const EqualizerPanel(showPanel: false),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        at(88 - 30, 715, 703 + 60, 61, _Seek(player: player)),
        at(
          808,
          727,
          75,
          43,
          _PixelButton(
            asset: UiAssets.termEq,
            label: 'Equalizer',
            lit: eq > 0.5,
            onTap: onEqualizer,
          ),
        ),
        at(
          896,
          727,
          75,
          43,
          _PixelButton(
            asset: UiAssets.termAmbient,
            label: player.ambient ? 'Ambient on' : 'Ambient off',
            lit: player.ambient,
            onTap: () => player.setAmbient(!player.ambient),
          ),
        ),
      ],
    );
  }
}

/// Black seek line with the round playhead knob. Drag or tap to seek.
class _Seek extends StatefulWidget {
  const _Seek({required this.player});
  final PlayerController player;

  @override
  State<_Seek> createState() => _SeekState();
}

class _SeekState extends State<_Seek> {
  double? _drag; // 0..1 while dragging

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    final player = widget.player;
    return LayoutBuilder(builder: (context, c) {
      final inset = f(30); // the line starts 30 px in from this box
      final width = c.maxWidth - inset * 2;
      double fraction(Offset local) =>
          ((local.dx - inset) / width).clamp(0.0, 1.0).toDouble();
      void seekTo(double v) {
        final total = player.duration;
        if (total > Duration.zero) {
          player.seek(total * v);
        }
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) =>
            setState(() => _drag = fraction(d.localPosition)),
        onHorizontalDragUpdate: (d) =>
            setState(() => _drag = fraction(d.localPosition)),
        onHorizontalDragEnd: (_) {
          final v = _drag;
          setState(() => _drag = null);
          if (v != null) seekTo(v);
        },
        onTapUp: (d) => seekTo(fraction(d.localPosition)),
        child: StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, snap) {
            final total = player.duration.inMilliseconds;
            final pos = (snap.data ?? Duration.zero).inMilliseconds;
            final v = _drag ??
                (total <= 0 ? 0.0 : (pos / total).clamp(0.0, 1.0).toDouble());
            final knob = c.maxHeight;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: inset,
                  width: width,
                  top: c.maxHeight / 2 + f(6) - f(7.5),
                  height: f(15),
                  child: const ColoredBox(color: Colors.black),
                ),
                Positioned(
                  left: inset + width * v - knob / 2,
                  top: 0,
                  width: knob,
                  height: knob,
                  child: Image.asset(UiAssets.termPlayhead,
                      filterQuality: FilterQuality.medium),
                ),
              ],
            );
          },
        ),
      );
    });
  }
}
