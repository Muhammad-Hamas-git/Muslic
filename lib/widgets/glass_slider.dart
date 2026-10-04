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
  });

  final double value, min, max, origin, thickness, knob;
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
    canvas.drawCircle(at(frac(value)), knob, Paint()..color = Palette.knob);
  }

  @override
  bool shouldRepaint(_SliderPainter o) =>
      o.value != value ||
      o.min != min ||
      o.max != max ||
      o.origin != origin ||
      o.thickness != thickness ||
      o.knob != knob ||
      o.horizontal != horizontal;
}
