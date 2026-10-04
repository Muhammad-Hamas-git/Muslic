import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Paints an asset image with a layer blend mode, like Figma's
/// "Layer > Screen". Flutter's Image widget cannot do this (its blend mode
/// only applies to a colour tint), so the image is drawn directly onto the
/// canvas, where it blends with whatever was painted beneath it.
///
/// For the blend to see the background, nothing between this widget and
/// the background may isolate it into its own layer (an Opacity below 1,
/// a ShaderMask, ...). Fade it with [opacity] instead, which is applied as
/// paint alpha.
///
/// [sliceInsets] turns on nine-slice scaling (in source image px): the
/// corners keep their proportions while the middle stretches. Corners are
/// scaled by [sliceScale] (on-screen px per source px).
class BlendImage extends StatefulWidget {
  const BlendImage(
    this.asset, {
    super.key,
    this.blendMode = BlendMode.screen,
    this.opacity = 1.0,
    this.sliceInsets,
    this.sliceScale = 1.0,
  });

  final String asset;
  final BlendMode blendMode;
  final double opacity;
  final EdgeInsets? sliceInsets;
  final double sliceScale;

  @override
  State<BlendImage> createState() => _BlendImageState();
}

class _BlendImageState extends State<BlendImage> {
  ImageStream? _stream;
  ImageInfo? _info;
  late final ImageStreamListener _listener =
      ImageStreamListener((info, _) => setState(() => _info = info));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(BlendImage old) {
    super.didUpdateWidget(old);
    if (old.asset != widget.asset) _resolve();
  }

  void _resolve() {
    final stream = AssetImage(widget.asset)
        .resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _BlendPainter(
        image: _info?.image,
        mode: widget.blendMode,
        opacity: widget.opacity,
        slice: widget.sliceInsets,
        sliceScale: widget.sliceScale,
      ),
    );
  }
}

class _BlendPainter extends CustomPainter {
  _BlendPainter({
    required this.image,
    required this.mode,
    required this.opacity,
    required this.slice,
    required this.sliceScale,
  });

  final ui.Image? image;
  final BlendMode mode;
  final double opacity;
  final EdgeInsets? slice;
  final double sliceScale;

  @override
  void paint(Canvas canvas, Size size) {
    final im = image;
    if (im == null || opacity <= 0 || size.isEmpty) return;
    final paint = Paint()
      ..blendMode = mode
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = false
      ..color = Color.fromRGBO(0, 0, 0, opacity.clamp(0.0, 1.0));
    final w = im.width.toDouble(), h = im.height.toDouble();

    final s = slice;
    if (s == null) {
      canvas.drawImageRect(
          im, Rect.fromLTWH(0, 0, w, h), Offset.zero & size, paint);
      return;
    }

    // Nine-slice: source columns/rows and destination columns/rows.
    final sx = [0.0, s.left, w - s.right, w];
    final sy = [0.0, s.top, h - s.bottom, h];
    final dl = (s.left * sliceScale).clamp(0.0, size.width / 2);
    final dr = (s.right * sliceScale).clamp(0.0, size.width / 2);
    final dt = (s.top * sliceScale).clamp(0.0, size.height / 2);
    final db = (s.bottom * sliceScale).clamp(0.0, size.height / 2);
    final dx = [0.0, dl, size.width - dr, size.width];
    final dy = [0.0, dt, size.height - db, size.height];
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        final src = Rect.fromLTRB(sx[c], sy[r], sx[c + 1], sy[r + 1]);
        final dst = Rect.fromLTRB(dx[c], dy[r], dx[c + 1], dy[r + 1]);
        if (src.isEmpty || dst.isEmpty) continue;
        canvas.drawImageRect(im, src, dst, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BlendPainter old) =>
      old.image != image ||
      old.mode != mode ||
      old.opacity != opacity ||
      old.slice != slice ||
      old.sliceScale != sliceScale;
}

/// A tappable [BlendImage] that dips slightly while pressed.
class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.asset,
    required this.onTap,
    required this.width,
    required this.height,
    this.blendMode = BlendMode.screen,
    this.opacity = 1.0,
    this.semanticLabel,
  });

  final String asset;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final BlendMode blendMode;
  final double opacity;
  final String? semanticLabel;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.9 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: BlendImage(widget.asset,
                blendMode: widget.blendMode, opacity: widget.opacity),
          ),
        ),
      ),
    );
  }
}
