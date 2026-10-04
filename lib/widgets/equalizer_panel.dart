import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/player_controller.dart';
import '../ui/design.dart';
import 'blend_image.dart';
import 'glass_slider.dart';

/// Equalizer, speed and pitch, shown inside the player card in place of
/// the album art. Uses the same glass panel image as the control panel.
class EqualizerPanel extends StatelessWidget {
  const EqualizerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    final player = context.watch<PlayerController>();
    final pad = f(56);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Panel image is 1180 px wide for a 787 Figma px panel, so its
        // corners are drawn at 787/1180 of source size, scaled to screen.
        BlendImage(
          UiAssets.panel,
          sliceInsets: const EdgeInsets.all(110),
          sliceScale: f(787) / 1180,
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(pad, f(40), pad, f(44)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                title: 'Equalizer',
                trailing: [
                  _Pill(
                    label: player.eqEnabled ? 'On' : 'Off',
                    active: player.eqEnabled,
                    onTap: player.eqReady
                        ? () => player.setEqEnabled(!player.eqEnabled)
                        : null,
                  ),
                  SizedBox(width: f(20)),
                  _Pill(
                    label: 'Reset',
                    onTap: () {
                      player.resetEqualizer();
                      player.resetRates();
                    },
                  ),
                ],
              ),
              SizedBox(height: f(24)),
              Expanded(child: _Bands(player: player)),
              SizedBox(height: f(28)),
              _RateRow(
                label: 'Speed',
                value: player.speed,
                display: '${player.speed.toStringAsFixed(2)}x',
                min: PlayerController.minRate,
                max: PlayerController.maxRate,
                origin: 1.0,
                onChanged: player.setSpeed,
                onReset: () => player.setSpeed(1.0),
              ),
              _RateRow(
                label: 'Pitch',
                value: player.pitch,
                display: '${player.pitch.toStringAsFixed(2)}x',
                min: PlayerController.minRate,
                max: PlayerController.maxRate,
                origin: 1.0,
                onChanged: player.setPitch,
                onReset: () => player.setPitch(1.0),
              ),
              _RateRow(
                label: 'Boost',
                value: player.gainDb,
                display: '+${player.gainDb.toStringAsFixed(1)} dB',
                min: 0,
                max: 12,
                onChanged: player.setGainDb,
                onReset: () => player.setGainDb(0),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.trailing});
  final String title;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Txt.inter(f(40), FontWeight.w700)),
        ),
        ...trailing,
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.onTap, this.active = false});
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: f(28), vertical: f(10)),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: active ? 0.28 : 0.12),
          borderRadius: BorderRadius.circular(f(40)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Text(label,
            style: Txt.inter(f(26), FontWeight.w500,
                color: onTap == null
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.white)),
      ),
    );
  }
}

class _Bands extends StatelessWidget {
  const _Bands({required this.player});
  final PlayerController player;

  String _freq(double hz) =>
      hz >= 1000 ? '${(hz / 1000).toStringAsFixed(hz >= 10000 ? 0 : 1)}k' : '${hz.round()}';

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    if (!player.eqReady) {
      return Center(
        child: Text(
          'Play a song to use the equalizer.',
          textAlign: TextAlign.center,
          style: Txt.inter(f(28), FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.75)),
        ),
      );
    }
    final dim = player.eqEnabled ? 1.0 : 0.4;
    final label = Txt.inter(f(22), FontWeight.w500,
        color: Colors.white.withValues(alpha: 0.8 * dim));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        for (var i = 0; i < player.eqFrequencies.length; i++)
          Expanded(
            child: Column(
              children: [
                Text(
                    '${player.eqGains[i] >= 0 ? '+' : ''}'
                    '${player.eqGains[i].toStringAsFixed(0)}',
                    style: label),
                SizedBox(height: f(8)),
                Expanded(
                  child: Opacity(
                    opacity: dim,
                    child: GlassSlider(
                      axis: Axis.vertical,
                      value: player.eqGains[i],
                      min: player.eqMinDb,
                      max: player.eqMaxDb,
                      origin: 0,
                      thickness: f(5),
                      knobRadius: f(13),
                      onChanged: (v) => player.setBandGain(i, v),
                      onDoubleTap: () => player.setBandGain(i, 0),
                    ),
                  ),
                ),
                SizedBox(height: f(8)),
                Text(_freq(player.eqFrequencies[i]), style: label),
              ],
            ),
          ),
      ],
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({
    required this.label,
    required this.value,
    required this.display,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onReset,
    this.origin,
  });

  final String label;
  final double value;
  final String display;
  final double min;
  final double max;
  final double? origin;
  final ValueChanged<double> onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    final text = Txt.inter(f(26), FontWeight.w500);
    return SizedBox(
      height: f(64),
      child: Row(
        children: [
          SizedBox(width: f(110), child: Text(label, style: text)),
          Expanded(
            child: GlassSlider(
              value: value,
              min: min,
              max: max,
              origin: origin,
              thickness: f(5),
              knobRadius: f(13),
              onChanged: onChanged,
              onDoubleTap: onReset,
            ),
          ),
          SizedBox(
            width: f(130),
            child: Text(display, textAlign: TextAlign.right, style: text),
          ),
        ],
      ),
    );
  }
}
