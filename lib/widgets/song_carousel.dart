import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../debug/ui_tuning.dart';
import '../models/track.dart';
import '../ui/design.dart';
import 'art.dart';

/// The library carousel from Figma: a vertical stack of album covers on
/// the right, the centred one large with a shadow, neighbours shrinking and
/// washing out to white. The centred song's title and artist run vertically
/// down the left side.
///
/// How it scrolls: an invisible list sits on top and owns all the gesture
/// and fling physics (snapping to one song per [CarouselTuning.scrollStep]).
/// The covers are drawn from its scroll offset every frame, so sizes,
/// positions and the white wash change continuously instead of in steps.
/// Only the ~7 covers near the centre exist at any time.
class SongCarousel extends StatefulWidget {
  const SongCarousel({
    super.key,
    required this.tracks,
    required this.topBound,
    required this.bottomBound,
    required this.onSelect,
    this.focusTrackId,
  });

  final List<Track> tracks;

  /// When this changes to a song in [tracks], the carousel jumps to it
  /// (used to show the restored last song on launch).
  final int? focusTrackId;

  /// Screen y of the app bar bottom and the mini player top. The centred
  /// cover sits between them at [CarouselTuning.centerFraction].
  final double topBound;
  final double bottomBound;

  /// Called when the centred cover is tapped.
  final void Function(int index) onSelect;

  @override
  State<SongCarousel> createState() => _SongCarouselState();
}

class _SongCarouselState extends State<SongCarousel> {
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<int> _centered = ValueNotifier(0);
  double _step = 1;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    if (widget.focusTrackId != null) _jumpToFocus();
  }

  @override
  void didUpdateWidget(SongCarousel old) {
    super.didUpdateWidget(old);
    final changed = old.tracks.length != widget.tracks.length ||
        (widget.tracks.isNotEmpty &&
            old.tracks.isNotEmpty &&
            old.tracks.first.id != widget.tracks.first.id);
    if (widget.focusTrackId != null &&
        widget.focusTrackId != old.focusTrackId) {
      _jumpToFocus();
    } else if (changed && _scroll.hasClients) {
      _scroll.jumpTo(0);
      _centered.value = 0;
    }
  }

  void _jumpToFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final i = widget.tracks.indexWhere((t) => t.id == widget.focusTrackId);
      if (i < 0 || !mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(i * _step);
      _centered.value = i;
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _centered.dispose();
    super.dispose();
  }

  double get _page => _scroll.hasClients ? _scroll.offset / _step : 0;

  void _onScroll() {
    final n = widget.tracks.length;
    if (n == 0) return;
    final i = _page.round().clamp(0, n - 1);
    if (i != _centered.value) _centered.value = i;
  }

  /// Scrolls so [index] is centred.
  void scrollTo(int index) {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(index * _step,
        duration: CarouselTuning.tapScroll, curve: Curves.easeOutCubic);
  }

  // Piecewise-linear lookup in a tuning table by distance from centre.
  static double _lerpTable(List<double> t, double d) {
    if (d >= t.length - 1) return t.last;
    final i = d.floor();
    return t[i] + (t[i + 1] - t[i]) * (d - i);
  }

  double _centerY() =>
      widget.topBound +
      (widget.bottomBound - widget.topBound) * CarouselTuning.centerFraction;

  /// On-screen rect of cover [i] for the current scroll position.
  Rect _rectFor(int i, Fg f) {
    final d = i - _page;
    final ad = d.abs();
    final size = f(_lerpTable(CarouselTuning.size, ad));
    final off = f(_lerpTable(CarouselTuning.offset, ad)) * d.sign;
    final right = f(CarouselTuning.rightEdge);
    final cy = _centerY() + off;
    return Rect.fromLTWH(right - size, cy - size / 2, size, size);
  }

  void _onTapUp(TapUpDetails details, Fg f) {
    final n = widget.tracks.length;
    if (n == 0) return;
    final p = _page;
    final candidates = [
      for (var i = math.max(0, p.floor() - 3);
          i <= math.min(n - 1, p.ceil() + 3);
          i++)
        i
    ]..sort((a, b) => (a - p).abs().compareTo((b - p).abs()));
    for (final i in candidates) {
      if (_rectFor(i, f).contains(details.localPosition)) {
        if ((i - p).abs() < 0.5) {
          widget.onSelect(i);
        } else {
          scrollTo(i);
        }
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    _step = f(CarouselTuning.scrollStep);
    final tracks = widget.tracks;

    return LayoutBuilder(builder: (context, c) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (d) => _onTapUp(d, f),
        child: Stack(
          children: [
            // Covers, redrawn from the scroll offset.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _scroll,
                builder: (context, _) => _covers(f),
              ),
            ),
            // Vertical title + artist of the centred song.
            Positioned.fill(
              child: ValueListenableBuilder<int>(
                valueListenable: _centered,
                builder: (context, i, _) => tracks.isEmpty
                    ? const SizedBox.shrink()
                    : _SideTitle(
                        track: tracks[i.clamp(0, tracks.length - 1)],
                        centerY: _centerY() + f(55),
                      ),
              ),
            ),
            // Invisible list that drives scrolling.
            Positioned.fill(
              child: ScrollConfiguration(
                behavior: const _NoGlow(),
                child: ListView.builder(
                  controller: _scroll,
                  physics: _SnapPhysics(step: _step),
                  itemExtent: _step,
                  padding:
                      EdgeInsets.only(bottom: math.max(0, c.maxHeight - _step)),
                  itemCount: tracks.length,
                  itemBuilder: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _covers(Fg f) {
    final tracks = widget.tracks;
    final n = tracks.length;
    if (n == 0) return const SizedBox.shrink();
    final p = _page;
    final from = math.max(0, (p - 3.5).floor());
    final to = math.min(n - 1, (p + 3.5).ceil());
    // Farthest first so the centred cover paints on top.
    final order = [for (var i = from; i <= to; i++) i]
      ..sort((a, b) => (b - p).abs().compareTo((a - p).abs()));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final i in order)
          if ((i - p).abs() <= 3.5)
            Positioned.fromRect(
              key: ValueKey(tracks[i].id),
              rect: _rectFor(i, f),
              child: _Cover(
                track: tracks[i],
                distance: (i - p).abs(),
                f: f,
              ),
            ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.track, required this.distance, required this.f});

  final Track track;
  final double distance;
  final Fg f;

  @override
  Widget build(BuildContext context) {
    final wash = distance <= 3
        ? _SongCarouselState._lerpTable(CarouselTuning.whiteWash, distance)
        : CarouselTuning.whiteWash.last +
            (1 - CarouselTuning.whiteWash.last) * ((distance - 3) / 0.5);
    final shadow = (1 - distance * 2).clamp(0.0, 1.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: shadow <= 0
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25 * shadow),
                  offset: Offset(0, f(4)),
                  blurRadius: f(75),
                  spreadRadius: f(25),
                ),
              ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          TrackArt(track: track, decodeWidth: 640),
          if (wash > 0)
            ColoredBox(
                color: Colors.white.withValues(alpha: wash.clamp(0.0, 1.0))),
        ],
      ),
    );
  }
}

class _SideTitle extends StatelessWidget {
  const _SideTitle({required this.track, required this.centerY});

  final Track track;
  final double centerY;

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    final length = f(1266);

    Widget column(String text, TextStyle style, double centerX, double thick) {
      return Positioned(
        left: centerX - thick / 2,
        top: centerY - length / 2,
        width: thick,
        height: length,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: RotatedBox(
            key: ValueKey('${track.id}$text'),
            quarterTurns: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(text, maxLines: 1, style: style),
            ),
          ),
        ),
      );
    }

    return IgnorePointer(
      child: Stack(
        children: [
          column(
            track.title.toUpperCase(),
            Txt.kumbh(f(96), letterSpacing: f(29.76)),
            f(95.5),
            f(119),
          ),
          column(
            track.artist,
            Txt.kumbh(f(48), color: Palette.muted),
            f(208),
            f(60),
          ),
        ],
      ),
    );
  }
}

/// Snaps to whole songs, but lets a fling carry across many songs first.
class _SnapPhysics extends ScrollPhysics {
  const _SnapPhysics({required this.step, super.parent});

  final double step;

  @override
  _SnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _SnapPhysics(step: step, parent: buildParent(ancestor));

  @override
  ScrollPhysics buildParent(ScrollPhysics? ancestor) =>
      const ClampingScrollPhysics().applyTo(ancestor);

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    // Same approach as Flutter's FixedExtentScrollPhysics: find where a
    // natural fling would stop, round that to a song, then glide there.
    final natural = super.createBallisticSimulation(position, velocity);
    final end = natural?.x(double.infinity) ?? position.pixels;
    final target = ((end / step).round() * step)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    final tol = toleranceFor(position);
    if ((target - position.pixels).abs() < tol.distance &&
        velocity.abs() < tol.velocity) {
      return null;
    }
    final sameSong = (target / step).round() == (position.pixels / step).round();
    final towardTarget = (target - position.pixels).sign == velocity.sign;
    if (sameSong || !towardTarget || velocity.abs() <= tol.velocity) {
      return ScrollSpringSimulation(
        const SpringDescription(mass: 1, stiffness: 120, damping: 22),
        position.pixels,
        target,
        velocity,
        tolerance: tol,
      );
    }
    return FrictionSimulation.through(
        position.pixels, target, velocity, tol.velocity * velocity.sign);
  }

  @override
  bool get allowImplicitScrolling => false;
}

class _NoGlow extends ScrollBehavior {
  const _NoGlow();
  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}
