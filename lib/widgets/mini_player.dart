import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/player_screen.dart';
import '../state/player_controller.dart';
import 'artwork.dart';

/// Compact persistent player docked at the bottom of the library screen.
/// Tapping it opens the full player; it can be swiped down (tabbed away)
/// from the full player without stopping playback.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final track = player.current;
    if (track == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: GestureDetector(
        onTap: () => PlayerScreen.open(context),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -200) PlayerScreen.open(context);
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  TrackArtwork(trackId: track.id, size: 48, borderRadius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        Text(track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: player.previous,
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  IconButton.filled(
                    onPressed: player.togglePlay,
                    icon: Icon(player.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded),
                  ),
                  IconButton(
                    onPressed: player.next,
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (context, snap) {
                  final pos = snap.data ?? Duration.zero;
                  final total = player.duration;
                  final v = total.inMilliseconds == 0
                      ? 0.0
                      : (pos.inMilliseconds / total.inMilliseconds)
                          .clamp(0.0, 1.0);
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: v,
                      minHeight: 3,
                      backgroundColor:
                          scheme.onSurface.withValues(alpha: 0.08),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
