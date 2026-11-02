import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../debug/terminal_tuning.dart';

/// Shared loading and parameter plumbing for shaders/crt.frag.
class Crt {
  Crt._();

  static ui.FragmentProgram? _program;
  static Future<ui.FragmentProgram?>? _loading;

  /// Off in widget tests that need still frames.
  static bool animate = true;

  /// The whole-screen effect needs Flutter's Impeller renderer (used on
  /// Android by default). Elsewhere widgets are drawn without it.
  static bool get filterSupported {
    try {
      return ui.ImageFilter.isShaderFilterSupported;
    } catch (_) {
      return false;
    }
  }

  static ui.FragmentProgram? get program => _program;

  static Future<ui.FragmentProgram?> load() => _loading ??= () async {
        try {
          return _program =
              await ui.FragmentProgram.fromAsset('shaders/crt.frag');
        } catch (e) {
          debugPrint('müslic: CRT shader unavailable: $e');
          return null;
        }
      }();

  static final Stopwatch _clock = Stopwatch()..start();

  static double _time(CrtParams p) =>
      animate ? (_clock.elapsedMilliseconds * 0.001 * p.speed) % 1024 : 2.0;

  /// Writes [p] into [s]. [size] is the drawing size in shader pixels,
  /// [logical] the same area in points; [img] picks the part of the
  /// texture to show (0..1, used to crop album art like BoxFit.cover).
  /// Sizes in [p] (scanline size, mask size, dispersion...) are Figma px,
  /// so [logical] is converted to Figma px with [figma] (points per Figma
  /// px) before it reaches the shader.
  static void apply(
    ui.FragmentShader s,
    CrtParams p, {
    required Size size,
    required Size logical,
    required double scale,
    required double figma,
    Rect img = const Rect.fromLTWH(0, 0, 1, 1),
  }) {
    var i = 0;
    void f(double v) => s.setFloat(i++, v);
    f(size.width);
    f(size.height);
    f(p.curvature / 100);
    f(p.scanlines / 100);
    f(p.mask / 100);
    f(p.aberration / 100 * 12);
    f(_pow2(p.brightness));
    f(p.scanlineSize);
    f(_time(p));
    f(p.flicker / 100);
    f(p.noise / 100);
    f(p.rollSpeed);
    f(p.jitter / 100);
    f(p.noiseSize);
    f(p.clipToCurve ? 1 : 0);
    f(p.maskPitch);
    f(p.vignette / 100);
    f(scale * figma);
    f(logical.width / figma);
    f(logical.height / figma);
    f(img.width);
    f(img.height);
    f(img.left);
    f(img.top);
  }

  static double _pow2(double x) => math.pow(2, x).toDouble();
}

/// Runs a ticker while mounted (and visible), for animated CRT widgets.
mixin _CrtTick<T extends StatefulWidget> on SingleTickerProviderStateMixin<T> {
  final ValueNotifier<int> tick = ValueNotifier(0);
  late final Ticker _ticker = createTicker((_) => tick.value++);

  void startTicking() {
    Crt.load().then((_) {
      if (!mounted) return;
      setState(() {});
      if (Crt.animate && !_ticker.isActive) _ticker.start();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    tick.dispose();
    super.dispose();
  }
}

/// Puts [child] behind CRT glass (scanlines, jitter, dispersion, flicker,
/// static, rolling bar). Uses the GPU shader as an image filter where the
/// renderer supports it; otherwise shows [child] with plain scanlines.
class CrtFilter extends StatefulWidget {
  const CrtFilter({
    super.key,
    required this.params,
    required this.child,
    this.fallbackScanlines = false,
  });

  final CrtParams params;
  final Widget child;

  /// Draw simple scanlines when the shader filter is not available.
  final bool fallbackScanlines;

  @override
  State<CrtFilter> createState() => _CrtFilterState();
}

class _CrtFilterState extends State<CrtFilter>
    with SingleTickerProviderStateMixin<CrtFilter>, _CrtTick<CrtFilter> {
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    if (Crt.filterSupported) startTicking();
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final program = Crt.program;
    if (!Crt.filterSupported || program == null) {
      if (!widget.fallbackScanlines) return widget.child;
      return Stack(fit: StackFit.passthrough, children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _Scanlines(widget.params)),
          ),
        ),
      ]);
    }
    final shader = _shader ??= program.fragmentShader();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final figma = MediaQuery.sizeOf(context).width / 1080;
    return LayoutBuilder(builder: (context, c) {
      final logical = c.biggest;
      return AnimatedBuilder(
        animation: tick,
        child: widget.child,
        builder: (context, child) {
          Crt.apply(shader, widget.params,
              size: logical * dpr,
              logical: logical,
              scale: dpr,
              figma: figma);
          return ImageFiltered(
            imageFilter: ui.ImageFilter.shader(shader),
            child: child,
          );
        },
      );
    });
  }
}

class _Scanlines extends CustomPainter {
  _Scanlines(this.p);
  final CrtParams p;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: (p.scanlines / 100) * 0.5);
    final step = p.scanlineSize * size.width / 1080;
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawRect(Rect.fromLTWH(0, y + step / 2, size.width, step / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_Scanlines old) => old.p != p;
}

/// An image file (album art) drawn through the CRT shader, cropped like
/// BoxFit.cover. Works on every renderer.
class CrtImage extends StatefulWidget {
  const CrtImage({
    super.key,
    required this.file,
    required this.params,
    this.decodeWidth = 512,
  });

  final File? file;
  final CrtParams params;
  final int decodeWidth;

  @override
  State<CrtImage> createState() => _CrtImageState();
}

class _CrtImageState extends State<CrtImage>
    with SingleTickerProviderStateMixin<CrtImage>, _CrtTick<CrtImage> {
  ImageStream? _stream;
  ImageInfo? _info;
  late final ImageStreamListener _listener =
      ImageStreamListener((info, _) {
    if (mounted) setState(() => _info = info);
  });
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    startTicking();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(CrtImage old) {
    super.didUpdateWidget(old);
    if (old.file?.path != widget.file?.path) _resolve();
  }

  void _resolve() {
    final file = widget.file;
    if (file == null) {
      _stream?.removeListener(_listener);
      _stream = null;
      setState(() => _info = null);
      return;
    }
    final provider = ResizeImage(FileImage(file),
        width: widget.decodeWidth, policy: ResizeImagePolicy.fit);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final program = Crt.program;
    if (program != null) _shader ??= program.fragmentShader();
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _CrtImagePainter(
          image: _info?.image,
          shader: _shader,
          params: widget.params,
          dpr: MediaQuery.devicePixelRatioOf(context),
          figma: MediaQuery.sizeOf(context).width / 1080,
          repaint: tick,
        ),
      ),
    );
  }
}

class _CrtImagePainter extends CustomPainter {
  _CrtImagePainter({
    required this.image,
    required this.shader,
    required this.params,
    required this.dpr,
    required this.figma,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final ui.Image? image;
  final ui.FragmentShader? shader;
  final CrtParams params;
  final double dpr;
  final double figma;

  @override
  void paint(Canvas canvas, Size size) {
    final im = image;
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    if (im == null) {
      canvas.drawRect(rect, Paint()..color = const Color(0xFF0A140A));
      return;
    }
    // Part of the image that fills the box (BoxFit.cover), in 0..1.
    final ia = im.width / im.height, ba = size.width / size.height;
    final crop = ia > ba
        ? Rect.fromLTWH((1 - ba / ia) / 2, 0, ba / ia, 1)
        : Rect.fromLTWH(0, (1 - ia / ba) / 2, 1, ia / ba);
    final s = shader;
    if (s == null) {
      canvas.drawImageRect(
        im,
        Rect.fromLTWH(crop.left * im.width, crop.top * im.height,
            crop.width * im.width, crop.height * im.height),
        rect,
        Paint()..filterQuality = FilterQuality.medium,
      );
      return;
    }
    Crt.apply(s, params,
        size: size, logical: size, scale: dpr, figma: figma, img: crop);
    s.setImageSampler(0, im);
    canvas.drawRect(rect, Paint()..shader = s);
  }

  @override
  bool shouldRepaint(_CrtImagePainter old) =>
      old.image != image || old.shader != shader || old.params != params;
}
