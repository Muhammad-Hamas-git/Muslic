import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';

import '../state/player_controller.dart';
import '../widgets/artwork.dart';

/// Full-screen player, opened as a modal sheet so it can be swiped away
/// ("tabbed away") while playback continues in the background.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  static void open(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.96,
        child: PlayerScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final track = player.current;
    final scheme = Theme.of(context).colorScheme;

    if (track == null) {
      return const Center(child: Text('Nothing playing'));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text('Now playing',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 1.2)),
              ),
              const _AdvancedButton(),
            ],
          ),
          const Spacer(),
          // Album art, center stage.
          LayoutBuilder(builder: (context, c) {
            final side = c.maxWidth.clamp(0.0, 360.0);
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 40,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: TrackArtwork(
                  trackId: track.id, size: side, borderRadius: 28),
            );
          }),
          const Spacer(),
          SizedBox(
            height: 32,
            child: track.title.length > 28
                ? Marquee(
                    text: track.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                    blankSpace: 60,
                    velocity: 28,
                    pauseAfterRound: const Duration(seconds: 2),
                  )
                : Center(
                    child: Text(track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
          ),
          const SizedBox(height: 4),
          Text('${track.artist} · ${track.album}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          const _SeekBar(),
          const SizedBox(height: 6),
          _MainControls(player: player),
          const SizedBox(height: 8),
          if (player.speed != 1.0 ||
              player.pitch != 1.0 ||
              player.gainDb != 0.0)
            _ActiveEffectsChip(player: player),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar();

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragValue;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:${m.padLeft(2, '0')}:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snap) {
        final total = player.duration;
        final pos = _dragValue != null
            ? Duration(milliseconds: _dragValue!.round())
            : (snap.data ?? Duration.zero);
        final max = total.inMilliseconds.toDouble().clamp(1.0, double.infinity);
        return Column(
          children: [
            Slider(
              value: pos.inMilliseconds.toDouble().clamp(0.0, max),
              max: max,
              onChanged: (v) => setState(() => _dragValue = v),
              onChangeEnd: (v) {
                player.seek(Duration(milliseconds: v.round()));
                setState(() => _dragValue = null);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(pos),
                      style: Theme.of(context).textTheme.labelSmall),
                  Text(_fmt(total),
                      style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MainControls extends StatelessWidget {
  const _MainControls({required this.player});
  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    IconData loopIcon;
    switch (player.loopMode) {
      case LoopMode.one:
        loopIcon = Icons.repeat_one_rounded;
      case LoopMode.all:
        loopIcon = Icons.repeat_rounded;
      case LoopMode.off:
        loopIcon = Icons.repeat_rounded;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(Icons.shuffle_rounded,
              color: player.shuffle ? scheme.primary : scheme.onSurfaceVariant),
          onPressed: player.toggleShuffle,
        ),
        IconButton(
          iconSize: 42,
          icon: const Icon(Icons.skip_previous_rounded),
          onPressed: player.previous,
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(18),
          ),
          onPressed: player.togglePlay,
          child: Icon(
            player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 40,
          ),
        ),
        IconButton(
          iconSize: 42,
          icon: const Icon(Icons.skip_next_rounded),
          onPressed: player.next,
        ),
        IconButton(
          icon: Icon(loopIcon,
              color: player.loopMode == LoopMode.off
                  ? scheme.onSurfaceVariant
                  : scheme.primary),
          onPressed: player.cycleLoopMode,
        ),
      ],
    );
  }
}

class _ActiveEffectsChip extends StatelessWidget {
  const _ActiveEffectsChip({required this.player});
  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (player.speed != 1.0) '${player.speed.toStringAsFixed(2)}x speed',
      if (player.pitch != 1.0) '${player.pitch.toStringAsFixed(2)}x pitch',
      if (player.gainDb != 0.0) '+${player.gainDb.toStringAsFixed(1)} dB',
    ];
    return ActionChip(
      avatar: const Icon(Icons.graphic_eq_rounded, size: 16),
      label: Text(parts.join(' · ')),
      onPressed: () => _AdvancedControlsSheet.open(context),
    );
  }
}

class _AdvancedButton extends StatelessWidget {
  const _AdvancedButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Speed, pitch and boost',
      icon: const Icon(Icons.tune_rounded),
      onPressed: () => _AdvancedControlsSheet.open(context),
    );
  }
}

/// Speed / pitch / amplification panel.
class _AdvancedControlsSheet extends StatelessWidget {
  const _AdvancedControlsSheet();

  static void open(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _AdvancedControlsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Playback lab',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                TextButton(
                  onPressed: player.resetAdvanced,
                  child: const Text('Reset all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ParamSlider(
              label: 'Speed',
              value: player.speed,
              min: 0.25,
              max: 3.0,
              divisions: 55,
              display: '${player.speed.toStringAsFixed(2)}x',
              presets: const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
              onChanged: (v) => player.setSpeed(v),
            ),
            _ParamSlider(
              label: 'Pitch',
              value: player.pitch,
              min: 0.5,
              max: 2.0,
              divisions: 30,
              display: '${player.pitch.toStringAsFixed(2)}x',
              presets: const [0.75, 0.9, 1.0, 1.1, 1.25],
              onChanged: (v) => player.setPitch(v),
            ),
            _ParamSlider(
              label: 'Boost',
              value: player.gainDb,
              min: 0,
              max: 12,
              divisions: 24,
              display: '+${player.gainDb.toStringAsFixed(1)} dB',
              presets: const [0, 3, 6, 9, 12],
              presetSuffix: ' dB',
              onChanged: (v) => player.setGainDb(v),
            ),
            const SizedBox(height: 4),
            Text(
              'Boost uses the system loudness enhancer, which limits peaks so louder never means clipped.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParamSlider extends StatelessWidget {
  const _ParamSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.presets,
    required this.onChanged,
    this.presetSuffix = 'x',
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final List<double> presets;
  final String presetSuffix;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.titleSmall)),
            Text(display,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final p in presets)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(presetSuffix == ' dB'
                        ? '+${p.toStringAsFixed(0)}$presetSuffix'
                        : '${p.toStringAsFixed(2)}$presetSuffix'),
                    selected: (value - p).abs() < 0.011,
                    onSelected: (_) => onChanged(p),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
