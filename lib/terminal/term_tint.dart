import 'package:flutter/widgets.dart';

import '../debug/terminal_tuning.dart';

/// Recolours the green Terminal art (logo, settings and search icons) to
/// the current palette. Phosphor draws the art untouched; Amber maps the
/// green channel onto [TerminalTuning.phosphor] so shading is kept.
class TermTint extends StatelessWidget {
  const TermTint({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!TerminalTuning.amber) return child;
    final c = TerminalTuning.phosphor;
    List<double> row(double v) => [v * 0.1, v, v * 0.1, 0, 0];
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(<double>[
        ...row(c.r), ...row(c.g), ...row(c.b), 0, 0, 0, 1, 0, //
      ]),
      child: child,
    );
  }

  /// Turns a full-colour image (the equalizer) into a one-colour screen in
  /// the current palette, by luminance.
  static ColorFilter mono() {
    final c = TerminalTuning.phosphor;
    final peak = [c.r, c.g, c.b].reduce((a, b) => a > b ? a : b);
    List<double> row(double v) {
      final k = peak == 0 ? 0.0 : v / peak;
      return [0.2126 * k, 0.7152 * k, 0.0722 * k, 0, 0];
    }
    // Phosphor keeps its old faint red/blue so it looks the same as before.
    final lift = TerminalTuning.amber ? 0.0 : 0.1;
    final r = row(c.r), g = row(c.g), b = row(c.b);
    for (var i = 0; i < 3; i++) {
      r[i] += lift * [0.2126, 0.7152, 0.0722][i];
      b[i] += lift * [0.2126, 0.7152, 0.0722][i];
    }
    return ColorFilter.matrix(<double>[...r, ...g, ...b, 0, 0, 0, 1, 0]);
  }
}
