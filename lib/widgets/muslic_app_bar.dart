import 'package:flutter/material.dart';

import '../ui/design.dart';
import '../ui/skin.dart';
import 'blend_image.dart';

/// The top bar on every screen: logo centred, optional icons left/right.
/// Positions follow Figma (logo 285 x 119 at y 55, icons 72 px at y 79),
/// shifted down to sit below the status bar.
class MuslicAppBar extends StatelessWidget {
  const MuslicAppBar({super.key, this.leading, this.trailing});

  final Widget? leading;
  final Widget? trailing;

  /// Figma y offset removed because the status bar already adds space.
  static const double statusShift = 40;

  /// Height of the bar below the status bar, in Figma px.
  static const double height = 174 - statusShift;

  static double bottom(BuildContext context) =>
      MediaQuery.paddingOf(context).top + Fg.of(context)(height);

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: top + f(height),
      child: Stack(
        children: [
          Positioned(
            top: top + f(55 - statusShift),
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(Skin.of(context).logo,
                  width: f(285), height: f(119), fit: BoxFit.contain),
            ),
          ),
          if (leading != null)
            Positioned(
                top: top + f(79 - statusShift), left: f(60), child: leading!),
          if (trailing != null)
            Positioned(
                top: top + f(79 - statusShift),
                right: f(1080 - 1020),
                child: trailing!),
        ],
      ),
    );
  }
}

/// A 72 px app bar icon from Figma, drawn at 75% opacity like the design.
class AppBarIcon extends StatelessWidget {
  const AppBarIcon(
      {super.key, required this.asset, required this.onTap, this.tooltip});

  final String asset;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    final tint = Skin.of(context).icon;
    return Bouncy(
      onTap: onTap,
      semanticLabel: tooltip,
      child: Opacity(
        opacity: 0.75,
        child: Image.asset(asset,
            width: f(72),
            height: f(72),
            // Dark theme: the black Figma icons are drawn white.
            color: tint,
            colorBlendMode: tint == null ? null : BlendMode.srcIn),
      ),
    );
  }
}

/// Same footprint as [AppBarIcon], for Material icons (back arrow, close).
class AppBarGlyph extends StatelessWidget {
  const AppBarGlyph(
      {super.key, required this.icon, required this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    final color = (Skin.of(context).icon ?? Colors.black).withValues(alpha: 0.75);
    return Bouncy(
      onTap: onTap,
      semanticLabel: tooltip,
      child: SizedBox(
        width: f(72),
        height: f(72),
        child: Icon(icon, size: f(72), color: color),
      ),
    );
  }
}
