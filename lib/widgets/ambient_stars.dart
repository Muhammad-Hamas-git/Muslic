import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../debug/ambient_tuning.dart';
import '../state/player_controller.dart';
import '../ui/skin.dart';

/// Twinkling stars on the black background while ambient mode is on.
/// Tuning: [StarTuning] in lib/debug/ambient_tuning.dart.
///
/// Every instance draws the same sky (same seed, positions as fractions of
/// its size, one shared clock), so a starfield behind the library and one
/// behind the open player line up exactly while the player fades in.
///
/// [opacity] scales the whole field. [weight] scales each star by its
/// height on screen, so a field drawn above the library's edge fades only
/// shows where the fades would have hidden the field below.
class AmbientStars extends StatefulWidget {
  const AmbientStars({super.key, this.opacity = 1, this.weight});

  final double opacity;
  final double Function(double y, Size size)? weight;

  /// Off in widget tests that need a still frame.
  static bool animate = true;

  @override
  State<AmbientStars> createState() => _AmbientStarsState();
}

class _AmbientStarsState extends State<AmbientStars>
    with TickerProviderStateMixin {
  static final Stopwatch _clock = Stopwatch()..start();

  late final AnimationController _show =
      AnimationController(vsync: this, duration: skinFade);
  final ValueNotifier<double> _time = ValueNotifier(0);
  late final Ticker _ticker = createTicker((_) {
    _time.value = _clock.elapsedMicroseconds / 1e6;
  });

  @override
  void initState() {
    super.initState();
    _show.addListener(_syncTicker);
  }

  void _syncTicker() {
    final run = _show.value > 0 && AmbientStars.animate;
    if (run && !_ticker.isActive) {
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _show.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = context.select<PlayerController, bool>((p) => p.ambient);
    final target = on ? 1.0 : 0.0;
    if (_goal == null) {
      // First build: start in the right state without fading.
      _goal = target;
      _show.value = target;
      // Still frames (tests) need a time that shows some stars.
      _time.value = _clock.elapsedMicroseconds / 1e6 + 1.3;
      _syncTicker();
    } else if (_goal != target) {
      _goal = target;
      _show.animateTo(target, curve: Curves.easeInOut);
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _StarPainter(
            time: _time,
            show: _show,
            opacity: widget.opacity,
            weight: widget.weight,
          ),
        ),
      ),
    );
  }

  double? _goal;
}

class _Star {
  const _Star(this.x, this.y, this.r, this.period, this.phase, this.peak);
  final double x, y, r, period, phase, peak;
}

final List<_Star> _sky = () {
  final rnd = math.Random(StarTuning.seed);
  // Jittered grid: random, but evenly spread (no clumps or empty halves).
  const n = StarTuning.count;
  final cols = math.max(1, math.sqrt(n * 0.46).round());
  final rows = (n / cols).ceil();
  final cells = [for (var i = 0; i < cols * rows; i++) i]..shuffle(rnd);
  final minT = StarTuning.minTwinkle.inMilliseconds / 1000;
  final maxT = StarTuning.maxTwinkle.inMilliseconds / 1000;
  return [
    for (final c in cells.take(n))
      _Star(
        (c % cols + 0.1 + 0.8 * rnd.nextDouble()) / cols,
        (c ~/ cols + 0.1 + 0.8 * rnd.nextDouble()) / rows,
        StarTuning.minRadius +
            (StarTuning.maxRadius - StarTuning.minRadius) *
                math.pow(rnd.nextDouble(), StarTuning.sizeBias),
        minT + (maxT - minT) * rnd.nextDouble(),
        rnd.nextDouble(),
        0.55 + 0.45 * rnd.nextDouble(),
      ),
  ];
}();

class _StarPainter extends CustomPainter {
  _StarPainter({
    required this.time,
    required this.show,
    required this.opacity,
    required this.weight,
  }) : super(repaint: Listenable.merge([time, show]));

  final ValueNotifier<double> time;
  final Animation<double> show;
  final double opacity;
  final double Function(double y, Size size)? weight;

  @override
  void paint(Canvas canvas, Size size) {
    final vis = show.value * opacity;
    if (vis <= 0 || size.isEmpty) return;
    final t = time.value;
    final core = Paint()..isAntiAlias = true;
    final halo = Paint()..isAntiAlias = true;
    for (final s in _sky) {
      final y = s.y * size.height;
      final w = weight == null ? 1.0 : weight!(y, size);
      if (w <= 0) continue;
      final wave = 0.5 - 0.5 * math.cos(2 * math.pi * (t / s.period + s.phase));
      final a = vis *
          w *
          s.peak *
          StarTuning.maxOpacity *
          math.pow(wave, StarTuning.offBias);
      if (a < 0.01) continue;
      final p = Offset(s.x * size.width, y);
      if (StarTuning.glow > 0 && s.r > 1.2) {
        halo
          ..color = Colors.white.withValues(alpha: a * 0.25 * StarTuning.glow)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.r * 1.6);
        canvas.drawCircle(p, s.r * 2.2, halo);
      }
      core.color = Colors.white.withValues(alpha: a);
      canvas.drawCircle(p, s.r, core);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.opacity != opacity || old.weight != weight;
}
