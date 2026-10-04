import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../debug/blur_tuning.dart';
import '../models/track.dart';
import '../services/artwork_cache.dart';

/// Sharp album art from the disk cache. Decoded at [decodeWidth] physical
/// px so the image cache holds one bitmap per song no matter how large the
/// tile is drawn, which keeps carousel scrolling smooth.
class TrackArt extends StatelessWidget {
  const TrackArt({
    super.key,
    required this.track,
    this.decodeWidth = 640,
    this.radius = 0,
  });

  final Track track;
  final int decodeWidth;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cache = context.read<ArtworkCache>();
    return ValueListenableBuilder<File?>(
      valueListenable: cache.sharp(track),
      builder: (context, file, _) {
        final Widget child = file == null
            ? const _ArtPlaceholder()
            : Image.file(
                file,
                key: ValueKey(file.path),
                fit: BoxFit.cover,
                cacheWidth: decodeWidth,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => const _ArtPlaceholder(),
              );
        return radius > 0
            ? ClipRRect(
                borderRadius: BorderRadius.circular(radius), child: child)
            : child;
      },
    );
  }
}

class _ArtPlaceholder extends StatelessWidget {
  const _ArtPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE9E9E6), Color(0xFFCFCFCB)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, c) => Center(
          child: Icon(Icons.music_note_rounded,
              size: c.biggest.shortestSide * 0.35,
              color: Colors.black.withValues(alpha: 0.18)),
        ),
      ),
    );
  }
}

/// The pre-blurred background for [track], cross-fading when the track
/// changes. Shows the fallback gradient until the blur exists.
class BlurredArt extends StatelessWidget {
  const BlurredArt({
    super.key,
    required this.track,
    this.zoom = 1.0,
    this.darken = 0.0,
  });

  final Track? track;
  final double zoom;
  final double darken;

  @override
  Widget build(BuildContext context) {
    final t = track;
    final cache = context.read<ArtworkCache>();
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [BlurTuning.fallbackTop, BlurTuning.fallbackBottom],
            ),
          ),
        ),
        if (t != null)
          ValueListenableBuilder<File?>(
            valueListenable: cache.blur(t),
            builder: (context, file, _) => AnimatedSwitcher(
              duration: BlurTuning.crossfade,
              layoutBuilder: (current, previous) => Stack(
                fit: StackFit.expand,
                children: [...previous, if (current != null) current],
              ),
              child: file == null
                  ? const SizedBox.expand(key: ValueKey('none'))
                  : Transform.scale(
                      key: ValueKey(file.path),
                      scale: zoom,
                      child: Image.file(
                        file,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        // Bilinear upscaling of an already-blurred image
                        // is smooth; no need for a pricier filter.
                        filterQuality: FilterQuality.low,
                        gaplessPlayback: true,
                      ),
                    ),
            ),
          ),
        if (darken > 0)
          ColoredBox(color: Colors.black.withValues(alpha: darken)),
      ],
    );
  }
}
