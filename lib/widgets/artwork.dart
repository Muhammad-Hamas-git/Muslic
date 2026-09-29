import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

/// Album art for a track, with a warm placeholder when none is embedded.
class TrackArtwork extends StatelessWidget {
  const TrackArtwork({
    super.key,
    required this.trackId,
    this.size = 200,
    this.borderRadius = 20,
  });

  final int trackId;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return QueryArtworkWidget(
      id: trackId,
      type: ArtworkType.AUDIO,
      keepOldArtwork: true,
      artworkQuality: FilterQuality.medium,
      artworkBorder: BorderRadius.circular(borderRadius),
      artworkWidth: size,
      artworkHeight: size,
      artworkFit: BoxFit.cover,
      size: size > 300 ? 1000 : 400,
      nullArtworkWidget: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.surfaceContainerHigh,
              scheme.surfaceContainerHighest,
            ],
          ),
        ),
        child: Icon(
          Icons.music_note_rounded,
          size: size * 0.4,
          color: scheme.primary.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
