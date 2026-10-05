import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../ui/design.dart';

/// The Figma playbar look (6 px white line, 50% white remainder, 30 px
/// light-grey knob), reused for seeking and for the speed/pitch/boost
/// sliders. Horizontal or vertical.
class GlassSlider extends StatefulWidget {
  const GlassSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onChangeEnd,
    this.axis = Axis.horizontal,
    this.origin,
    this.thickness,
    this.knobRadius,
    this.knobColor = Palette.knob,
    this.onDoubleTap,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final Axis axis;

  /// Where the filled part starts. Defaults to [min]; the equalizer uses 0
  /// so boosts fill upward and cuts fill downward.
  final double? origin;

  /// Line thickness and knob radius in logical px. Default: Figma's 6 and
  /// 15 Figma px.
  final double? thickness;
  final double? knobRadius;
  final Color knobColor;

  /// Usually "reset to default".
  final VoidCallback? onDoubleTap;

  @override
  State<GlassSlider> createState() => _GlassSliderState();
}

class _GlassSliderState extends State<GlassSlider> {
  double? _drag;

  double _toValue(Offset local, Size size, double knob) {
    final horizontal = widget.axis == Axis.horizontal;
    final len = (horizontal ? size.width : size.height) - knob * 2;
    var t = horizontal
        ? (local.dx - knob) / len
        : 1 - (local.dy - knob) / len; // bottom = min
    t = t.clamp(0.0, 1.0);
    return widget.min + (widget.max - widget.min) * t;
  }

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    final thick = widget.thickness ?? f(6);
    final knob = widget.knobRadius ?? f(15);
    final horizontal = widget.axis == Axis.horizontal;

    return LayoutBuilder(builder: (context, c) {
      final size = c.biggest;
      void update(Offset p) {
        final v = _toValue(p, size, knob);
        setState(() => _drag = v);
        widget.onChanged(v);
      }

      void end() {
        final v = _drag;
        setState(() => _drag = null);
        if (v != null) widget.onChangeEnd?.call(v);
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => update(d.localPosition),
        onTapUp: (_) => end(),
        onDoubleTap: widget.onDoubleTap,
        onHorizontalDragStart:
            horizontal ? (d) => update(d.localPosition) : null,
        onHorizontalDragUpdate:
            horizontal ? (d) => update(d.localPosition) : null,
        onHorizontalDragEnd: horizontal ? (_) => end() : null,
        onVerticalDragStart:
            horizontal ? null : (d) => update(d.localPosition),
        onVerticalDragUpdate:
            horizontal ? null : (d) => update(d.localPosition),
        onVerticalDragEnd: horizontal ? null : (_) => end(),
        child: CustomPaint(
          size: size,
          painter: _SliderPainter(
            value: _drag ?? widget.value,
            min: widget.min,
            max: widget.max,
            origin: widget.origin ?? widget.min,
            horizontal: horizontal,
            thickness: thick,
            knob: knob,
            knobColor: widget.knobColor,
          ),
        ),
      );
    });
  }
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({
    required this.value,
    required this.min,
    required this.max,
    required this.origin,
    required this.horizontal,
    required this.thickness,
    required this.knob,
    required this.knobColor,
  });

  final double value, min, max, origin, thickness, knob;
  final Color knobColor;
  final bool horizontal;

  @override
  void paint(Canvas canvas, Size size) {
    double frac(double v) =>
        max == min ? 0 : ((v - min) / (max - min)).clamp(0.0, 1.0);

    Offset at(double t) => horizontal
        ? Offset(knob + (size.width - knob * 2) * t, size.height / 2)
        : Offset(size.width / 2, size.height - knob - (size.height - knob * 2) * t);

    final rest = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = Colors.white
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(at(0), at(1), rest);
    canvas.drawLine(at(frac(origin)), at(frac(value)), fill);
    final c = at(frac(value));
    canvas.drawCircle(
        c.translate(0, knob * 0.12),
        knob * 1.05,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, knob * 0.25));
    canvas.drawCircle(c, knob, Paint()..color = knobColor);
  }

  @override
  bool shouldRepaint(_SliderPainter o) =>
      o.value != value ||
      o.min != min ||
      o.max != max ||
      o.origin != origin ||
      o.thickness != thickness ||
      o.knob != knob ||
      o.knobColor != knobColor ||
      o.horizontal != horizontal;
}

/// A slider that only lands on fixed values ([stops]), spaced evenly along
/// the track so each stop is equally easy to hit. Small dots mark the
/// stops; the fill runs from [origin] (usually the neutral value) to the
/// current stop. [onChanged] fires only when the stop changes.
class SnapSlider extends StatefulWidget {
  const SnapSlider({
    super.key,
    required this.stops,
    required this.value,
    required this.origin,
    required this.onChanged,
    this.thickness,
    this.knobRadius,
    this.knobColor = Colors.white,
  });

  final List<double> stops; // ascending
  final double value;
  final double origin;
  final ValueChanged<double> onChanged;
  final double? thickness;
  final double? knobRadius;
  final Color knobColor;

  @override
  State<SnapSlider> createState() => _SnapSliderState();
}

class _SnapSliderState extends State<SnapSlider> {
  int _nearest(double v) {
    var best = 0;
    for (var i = 1; i < widget.stops.length; i++) {
      if ((widget.stops[i] - v).abs() < (widget.stops[best] - v).abs()) {
        best = i;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    final thick = widget.thickness ?? f(6);
    final knob = widget.knobRadius ?? f(15);
    final n = widget.stops.length;

    return LayoutBuilder(builder: (context, c) {
      final size = c.biggest;
      void pick(Offset p) {
        final t = ((p.dx - knob) / (size.width - knob * 2)).clamp(0.0, 1.0);
        final i = (t * (n - 1)).round();
        final v = widget.stops[i];
        if (v != widget.value) {
          HapticFeedback.selectionClick();
          widget.onChanged(v);
        }
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => pick(d.localPosition),
        onHorizontalDragStart: (d) => pick(d.localPosition),
        onHorizontalDragUpdate: (d) => pick(d.localPosition),
        onDoubleTap: () => widget.onChanged(widget.origin),
        child: CustomPaint(
          size: size,
          painter: _SnapPainter(
            count: n,
            index: _nearest(widget.value),
            origin: _nearest(widget.origin),
            thickness: thick,
            knob: knob,
            knobColor: widget.knobColor,
          ),
        ),
      );
    });
  }
}

class _SnapPainter extends CustomPainter {
  _SnapPainter({
    required this.count,
    required this.index,
    required this.origin,
    required this.thickness,
    required this.knob,
    required this.knobColor,
  });

  final int count, index, origin;
  final double thickness, knob;
  final Color knobColor;

  @override
  void paint(Canvas canvas, Size size) {
    Offset at(int i) => Offset(
        knob + (size.width - knob * 2) * (count == 1 ? 0 : i / (count - 1)),
        size.height / 2);
    final rest = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = Colors.white
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(at(0), at(count - 1), rest);
    canvas.drawLine(at(origin), at(index), fill);
    for (var i = 0; i < count; i++) {
      canvas.drawCircle(at(i), thickness * 0.9,
          Paint()..color = Colors.white.withValues(alpha: i == origin ? 1 : 0.8));
    }
    final c = at(index);
    canvas.drawCircle(
        c.translate(0, knob * 0.12),
        knob * 1.05,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, knob * 0.25));
    canvas.drawCircle(c, knob, Paint()..color = knobColor);
  }

  @override
  bool shouldRepaint(_SnapPainter o) =>
      o.count != count ||
      o.index != index ||
      o.origin != origin ||
      o.thickness != thickness ||
      o.knob != knob ||
      o.knobColor != knobColor;
}
