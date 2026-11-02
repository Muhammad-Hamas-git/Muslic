import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../services/nav_sound.dart';
import '../state/settings_controller.dart';

/// Plays the Terminal theme's mechanical press sound when a finger goes
/// down on [child], and the release sound when it lifts. Does not take part
/// in gestures, so taps work as before. Off with Settings > Button sounds.
class MechSound extends StatelessWidget {
  const MechSound({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    bool on() => context.read<SettingsController>().buttonSounds;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        if (on()) NavSound.instance.button(down: true);
      },
      onPointerUp: (_) {
        if (on()) NavSound.instance.button(down: false);
      },
      child: child,
    );
  }
}
