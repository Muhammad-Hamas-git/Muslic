import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../debug/terminal_tuning.dart';
import '../debug/ui_tuning.dart';
import '../models/track.dart';
import '../ui/design.dart';
import '../widgets/art.dart';
import '../widgets/muslic_app_bar.dart';
import 'terminal_layout.dart';

/// The Terminal theme's carousel. Closed player: the same vertical stack as
/// the other themes, title and artist running down the left. Open player
/// ([expansion] 1): the covers float into a horizontal row with the
/// neighbours turned away in 3D, and the title and artist move to the top.
/// Everything in between is a smooth blend of the two.
///
/// Scrolling is vertical while the player is closed and sideways while it
/// is open; both move through the same list. The title shows the centred
/// song, not the playing one.
class TerminalCarousel extends StatefulWidget {
  const TerminalCarousel({
    super.key,
    required this.tracks,
    required this.expansion,
    required this.onSelect,
    this.onSongPassed,
    this.focusTrackId,
  });

  final List<Track> tracks;
  final Animation<double> expansion;
  final void Function(int index) onSelect;
  final VoidCallback? onSongPassed;
  final int? focusTrackId;

  @override
  State<TerminalCarousel> createState() => _TerminalCarouselState();
}

class _TerminalCarouselState extends State<TerminalCarousel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _page =
      AnimationController.unbounded(vsync: this);
  int _centered = 0;
  bool _silent = false;

  @override
  void initState() {
    super.initState();
    _page.addListener(_onPage);
    if (widget.focusTrackId != null) _focus(animate: false);
  }

  @override
  void didUpdateWidget(TerminalCarousel old) {
    super.didUpdateWidget(old);
    final changed = old.tracks.length != widget.tracks.length ||
        (widget.tracks.isNotEmpty &&
            old.tracks.isNotEmpty &&
            old.tracks.first.id != widget.tracks.first.id);
    if (widget.focusTrackId != null &&
        widget.focusTrackId != old.focusTrackId) {
      _focus(animate: true);
    } else if (changed) {
      _silent = true;
      _page.value = 0;
      _silent = false;
    }
  }

  void _focus({required bool animate}) {
    final i = widget.tracks.indexWhere((t) => t.id == widget.focusTrackId);
    if (i < 0) return;
    if (!animate) {
      _silent = true;
      _page.value = i.toDouble();
      _silent = false;
      return;
    }
    final distance = (i - _page.value).abs();
    final ms = (CarouselTuning.restoreScrollBase.inMilliseconds +
            CarouselTuning.restoreScrollPerSong.inMilliseconds * distance)
        .clamp(0, CarouselTuning.restoreScrollMax.inMilliseconds)
        .round();
    _silent = true;
    _page
        .animateTo(i.toDouble(),
            duration: Duration(milliseconds: math.max(1, ms)),
            curve: Curves.easeInOutCubic)
        .whenCompleteOrCancel(() => _silent = false);
  }

  void _onPage() {
    final n = widget.tracks.length;
    if (n == 0) return;
    final i = _page.value.round().clamp(0, n - 1);
    if (i != _centered) {
      setState(() => _centered = i);
      if (!_silent) widget.onSongPassed?.call();
    }
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  bool get _horizontal => widget.expansion.value >= 0.5;

  double _step(TerminalLayout l) =>
      _horizontal ? l.f(TerminalTuning.hSideOffset) : l.f(CarouselTuning.scrollStep);

  void _drag(DragUpdateDetails d, TerminalLayout l) {
    _page.stop();
    final delta = _horizontal ? d.delta.dx : d.delta.dy;
    final n = widget.tracks.length;
    var next = _page.value - delta / _step(l);
    // Rubber band past the ends.
    if (next < 0) next = _page.value - delta / _step(l) * 0.3;
    if (next > n - 1) next = _page.value - delta / _step(l) * 0.3;
    _page.value = next;
  }

  void _release(DragEndDetails d, TerminalLayout l) {
    final v = _horizontal ? d.velocity.pixelsPerSecond.dx : d.velocity.pixelsPerSecond.dy;
    final n = widget.tracks.length;
    if (n == 0) return;
    final target =
        (_page.value - v / _step(l) * 0.22).round().clamp(0, n - 1).toDouble();
    _page.animateTo(target,
        duration: TerminalTuning.snap, curve: Curves.easeOutCubic);
  }

  void _goTo(int i) => _page.animateTo(i.toDouble(),
      duration: CarouselTuning.tapScroll, curve: Curves.easeOutCubic);

  // ---- Geometry --------------------------------------------------------

  static double _table(List<double> t, double d) {
    if (d >= t.length - 1) return t.last;
    final i = d.floor();
    return t[i] + (t[i + 1] - t[i]) * (d - i);
  }

  double _verticalCentre(TerminalLayout l, BuildContext context) {
    final top = MuslicAppBar.bottom(context);
    final bottom = l.bar.top;
    return top + (bottom - top) * CarouselTuning.centerFraction;
  }

  double _horizontalScale(TerminalLayout l) =>
      ((l.roomBottom - l.roomTop) / l.f(763)).clamp(0.6, 1.0).toDouble();

  double _horizontalCentre(TerminalLayout l) =>
      l.roomTop + (l.roomBottom - l.roomTop) * 0.455;

  _Pose _pose(int i, TerminalLayout l, BuildContext context) {
    final f = l.f;
    final t = Curves.easeInOutCubic.transform(widget.expansion.value);
    final d = i - _page.value;
    final ad = d.abs();
    final sign = d < 0 ? -1.0 : 1.0;

    // Vertical (closed player), as in the other themes.
    final vSize = f(_table(CarouselTuning.size, ad));
    final vOff = f(_table(CarouselTuning.offset, ad)) * sign;
    final vCy = _verticalCentre(l, context) + vOff;
    final vRect = Rect.fromLTWH(
        f(CarouselTuning.rightEdge) - vSize, vCy - vSize / 2, vSize, vSize);
    final vWash = ad <= 3
        ? _table(CarouselTuning.whiteWash, ad)
        : CarouselTuning.whiteWash.last;
    final vFadeT = ((ad - CarouselTuning.fadeStart) /
            (CarouselTuning.fadeEnd - CarouselTuning.fadeStart))
        .clamp(0.0, 1.0);
    final vOpacity = 1 - vFadeT * vFadeT * (3 - 2 * vFadeT);

    // Horizontal (open player).
    final k = _horizontalScale(l);
    final near = math.min(ad, 1.0);
    final hSize = f(lerpDouble(
            TerminalTuning.hCentreSize, TerminalTuning.hSideSize, near)!) *
        k;
    final hCx = f(540) +
        sign *
            f(TerminalTuning.hSideOffset * near + math.max(0.0, ad - 1) * 170) *
            k;
    final hCy = _horizontalCentre(l);
    final hRect = Rect.fromCenter(
        center: Offset(hCx, hCy), width: hSize, height: hSize);
    final hAngle = sign * TerminalTuning.hSideAngle * near * math.pi / 180;
    final hWash = TerminalTuning.hSideWash * near;
    final hOpacity = (1 - (ad - 1.2) / 0.7).clamp(0.0, 1.0).toDouble();

    return _Pose(
      rect: Rect.lerp(vRect, hRect, t)!,
      angle: hAngle * t,
      wash: lerpDouble(vWash, hWash, t)!,
      opacity: lerpDouble(vOpacity, hOpacity, t)!,
      shadow: (1 - ad * 2).clamp(0.0, 1.0).toDouble(),
      t: t,
      distance: ad,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = TerminalLayout(context);
    final tracks = widget.tracks;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanUpdate: (d) => _drag(d, l),
      onPanEnd: (d) => _release(d, l),
      onTapUp: (d) => _tap(d.localPosition, l, context),
      child: AnimatedBuilder(
        animation: Listenable.merge([_page, widget.expansion]),
        builder: (context, _) {
          if (tracks.isEmpty) return const SizedBox.expand();
          final p = _page.value;
          final from = math.max(0, (p - 3.5).floor());
          final to = math.min(tracks.length - 1, (p + 3.5).ceil());
          final order = [for (var i = from; i <= to; i++) i]
            ..sort((a, b) => (b - p).abs().compareTo((a - p).abs()));
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final i in order)
                if (_pose(i, l, context) case final pose
                    when pose.opacity > 0.01)
                  Positioned.fromRect(
                    key: ValueKey(tracks[i].id),
                    rect: pose.rect,
                    child: _Cover(track: tracks[i], pose: pose, f: l.f),
                  ),
              Positioned.fill(
                child: _Titles(
                  track: tracks[_centered.clamp(0, tracks.length - 1)],
                  t: Curves.easeInOutCubic.transform(widget.expansion.value),
                  verticalCentre: _verticalCentre(l, context),
                  layout: l,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _tap(Offset pos, TerminalLayout l, BuildContext context) {
    final n = widget.tracks.length;
    if (n == 0) return;
    final p = _page.value;
    final candidates = [
      for (var i = math.max(0, p.floor() - 3);
          i <= math.min(n - 1, p.ceil() + 3);
          i++)
        i
    ]..sort((a, b) => (a - p).abs().compareTo((b - p).abs()));
    for (final i in candidates) {
      if (_pose(i, l, context).rect.contains(pos)) {
        if ((i - p).abs() < 0.5) {
          widget.onSelect(i);
        } else {
          _goTo(i);
        }
        return;
      }
    }
  }
}

class _Pose {
  const _Pose({
    required this.rect,
    required this.angle,
    required this.wash,
    required this.opacity,
    required this.shadow,
    required this.t,
    required this.distance,
  });
  final Rect rect;
  final double angle;
  final double wash;
  final double opacity;
  final double shadow;
  final double t; // 0 = vertical, 1 = horizontal
  final double distance;
}

class _Cover extends StatelessWidget {
  const _Cover({required this.track, required this.pose, required this.f});
  final Track track;
  final _Pose pose;
  final Fg f;

  @override
  Widget build(BuildContext context) {
    // Library: soft white glow under the centred cover; open player: a
    // dark drop shadow (Figma).
    final glow = Color.lerp(Colors.white.withValues(alpha: 0.25),
        Colors.black.withValues(alpha: 0.25), pose.t)!;
    Widget cover = DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: pose.shadow <= 0
            ? null
            : [
                BoxShadow(
                  color: glow.withValues(alpha: glow.a * pose.shadow),
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
          if (pose.wash > 0)
            ColoredBox(
                color: Colors.white
                    .withValues(alpha: pose.wash.clamp(0.0, 1.0).toDouble())),
        ],
      ),
    );
    if (pose.angle != 0) {
      cover = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, TerminalTuning.hPerspective)
          ..rotateY(pose.angle),
        child: cover,
      );
    }
    return pose.opacity >= 1
        ? cover
        : Opacity(opacity: pose.opacity, child: cover);
  }
}

/// Title (seven/fourteen-segment font) and artist of the centred song.
/// Vertical down the left in the library; horizontal at the top when the
/// player is open.
class _Titles extends StatelessWidget {
  const _Titles({
    required this.track,
    required this.t,
    required this.verticalCentre,
    required this.layout,
  });

  final Track track;
  final double t;
  final double verticalCentre;
  final TerminalLayout layout;

  @override
  Widget build(BuildContext context) {
    final l = layout;
    final f = l.f;

    Widget line({
      required String text,
      required TextStyle style,
      required Offset from,
      required Offset to,
      required double lengthFrom,
      required double lengthTo,
      required double thick,
    }) {
      final c = Offset.lerp(from, to, t)!;
      final w = lerpDouble(lengthFrom, lengthTo, t)!;
      return Positioned(
        left: c.dx - w / 2,
        top: c.dy - thick / 2,
        width: w,
        height: thick,
        child: Transform.rotate(
          angle: lerpDouble(-math.pi / 2, 0, t)!,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: FittedBox(
              key: ValueKey('${track.id}$text'),
              fit: BoxFit.scaleDown,
              child: Text(text, maxLines: 1, style: style),
            ),
          ),
        ),
      );
    }

    final titleSize = f(lerpDouble(112, 81, t)!);
    return IgnorePointer(
      child: Stack(
        children: [
          line(
            text: track.title.toUpperCase(),
            style: TextStyle(
              fontFamily: 'DSEG14',
              fontSize: titleSize,
              height: 1.1,
              color: TerminalTuning.phosphor,
              shadows: [
                Shadow(
                    color: TerminalTuning.titleGlow,
                    blurRadius: f(TerminalTuning.titleGlowBlur)),
              ],
            ),
            from: Offset(f(107.5), verticalCentre - f(35)),
            to: Offset(f(536.5), l.top(437)),
            lengthFrom: f(1150),
            lengthTo: f(900),
            thick: titleSize * 1.25,
          ),
          line(
            text: track.artist,
            style: Txt.kumbh(f(48), color: TerminalTuning.artist),
            from: Offset(f(208), verticalCentre + f(55)),
            to: Offset(f(536.5), l.top(517)),
            lengthFrom: f(1100),
            lengthTo: f(900),
            thick: f(64),
          ),
        ],
      ),
    );
  }
}
