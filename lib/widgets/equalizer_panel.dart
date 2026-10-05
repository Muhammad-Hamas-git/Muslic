import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../debug/ui_tuning.dart';
import '../state/player_controller.dart';
import '../ui/design.dart';
import 'blend_image.dart';
import 'glass_slider.dart';

/// Equalizer, speed, pitch and boost, shown inside the player card in
/// place of the album art. Uses the same glass panel image as the control
/// panel.
///
/// [fade] is applied as paint alpha to the glass background (so its screen
/// blend keeps working while it animates) and as a normal Opacity to the
/// controls on top, which are plain white drawings.
class EqualizerPanel extends StatelessWidget {
  const EqualizerPanel({super.key, this.fade = 1.0});

  final double fade;

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    final player = context.watch<PlayerController>();
    final pad = f(56);

    final controls = Padding(
      padding: EdgeInsets.fromLTRB(pad, f(40), pad, f(36)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text('Equalizer', style: Txt.inter(f(40), FontWeight.w700)),
              ),
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
          SizedBox(height: f(20)),
          Expanded(child: _Bands(player: player)),
          SizedBox(height: f(24)),
          _RateRow(
            label: 'Speed',
            display: '${_rate(player.speed)}x',
            slider: SnapSlider(
              stops: EqTuning.rateStops,
              value: player.speed,
              origin: 1.0,
              thickness: f(EqTuning.rateLine),
              knobRadius: f(EqTuning.rateKnob),
              onChanged: player.setSpeed,
            ),
          ),
          _RateRow(
            label: 'Pitch',
            display: '${_rate(player.pitch)}x',
            slider: SnapSlider(
              stops: EqTuning.rateStops,
              value: player.pitch,
              origin: 1.0,
              thickness: f(EqTuning.rateLine),
              knobRadius: f(EqTuning.rateKnob),
              onChanged: player.setPitch,
            ),
          ),
          _RateRow(
            label: 'Boost',
            display: player.gainDb == 0
                ? '0 dB'
                : '+${player.gainDb.toStringAsFixed(0)} dB',
            slider: SnapSlider(
              stops: EqTuning.boostStops,
              value: player.gainDb,
              origin: 0,
              thickness: f(EqTuning.rateLine),
              knobRadius: f(EqTuning.rateKnob),
              onChanged: player.setGainDb,
            ),
          ),
        ],
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // Panel image is 1180 px wide for a 787 Figma px panel, so its
        // corners are drawn at 787/1180 of source size, scaled to screen.
        BlendImage(
          UiAssets.panel,
          opacity: fade,
          sliceInsets: const EdgeInsets.all(110),
          sliceScale: f(787) / 1180,
        ),
        if (fade > 0)
          fade >= 1 ? controls : Opacity(opacity: fade, child: controls),
      ],
    );
  }

  static String _rate(double v) =>
      v.toStringAsFixed(v * 10 == (v * 10).roundToDouble() ? 1 : 2);
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

  static String _db(double g) {
    final r = g.round();
    return r > 0 ? '+$r' : '$r';
  }

  static String _freq(double hz) => hz >= 1000
      ? '${(hz / 1000).toStringAsFixed(hz >= 10000 ? 0 : 1)}k'
      : '${hz.round()}';

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
    final label = Txt.inter(f(24), FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.9 * dim));

    return Row(
      children: [
        for (var i = 0; i < player.eqFrequencies.length; i++)
          Expanded(
            child: Column(
              children: [
                Text(_db(player.eqGains[i]), style: label),
                SizedBox(height: f(6)),
                Expanded(
                  child: Opacity(
                    opacity: dim,
                    child: GlassSlider(
                      axis: Axis.vertical,
                      value: player.eqGains[i],
                      min: player.eqMinDb,
                      max: player.eqMaxDb,
                      origin: 0,
                      thickness: f(EqTuning.bandLine),
                      knobRadius: f(EqTuning.bandKnob),
                      knobColor: Colors.white,
                      onChanged: (v) => player.setBandGain(i, v),
                      onDoubleTap: () => player.setBandGain(i, 0),
                    ),
                  ),
                ),
                SizedBox(height: f(6)),
                Text(_freq(player.eqFrequencies[i]), style: label),
              ],
            ),
          ),
      ],
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow(
      {required this.label, required this.display, required this.slider});

  final String label;
  final String display;
  final Widget slider;

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    final text = Txt.inter(f(26), FontWeight.w500);
    return SizedBox(
      height: f(70),
      child: Row(
        children: [
          SizedBox(width: f(105), child: Text(label, style: text)),
          Expanded(child: slider),
          SizedBox(
            width: f(105),
            child: Text(display, textAlign: TextAlign.right, style: text),
          ),
        ],
      ),
    );
  }
}
