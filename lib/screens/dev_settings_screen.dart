import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../debug/dev_values.dart';
import '../ui/design.dart';
import '../ui/skin.dart';
import '../widgets/muslic_app_bar.dart';

/// Developer settings: every tuning value from lib/debug/*_tuning.dart as a
/// live slider, grouped. Changes apply immediately and are kept on the
/// phone. "Export" copies a JSON of all values (and which ones changed) to
/// the clipboard, ready to send and hardcode.
class DevSettingsScreen extends StatelessWidget {
  const DevSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = Skin.of(context);
    final f = Fg.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    final groups = <String, List<DevParam>>{};
    for (final p in DevValues.params) {
      groups.putIfAbsent(p.group, () => []).add(p);
    }

    return Scaffold(
      backgroundColor: skin.background,
      body: Column(
        children: [
          MuslicAppBar(
            leading: AppBarGlyph(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + bottom),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
                  child: Text('DEVELOPER',
                      style: Txt.kumbh(f(64),
                          color: skin.ink, letterSpacing: f(18))),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                  child: Text(
                    'Changes apply right away and stay on this phone. '
                    'Export copies them as JSON.',
                    style: Txt.inter(13, FontWeight.w400,
                        color: Palette.muted),
                  ),
                ),
                const _Actions(),
                const SizedBox(height: 14),
                for (final e in groups.entries)
                  _GroupTile(title: e.key, params: e.value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions();

  Future<void> _export(BuildContext context) async {
    final json = DevValues.exportJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Copied to clipboard'),
        content: SizedBox(
          width: double.maxFinite,
          height: 360,
          child: SingleChildScrollView(
            child: SelectableText(json,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Done')),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context) async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (!context.mounted) return;
    final ctrl = TextEditingController(text: clip?.text ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import JSON'),
        content: TextField(
          controller: ctrl,
          maxLines: 10,
          minLines: 4,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          decoration: const InputDecoration(hintText: 'Paste exported JSON'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text),
              child: const Text('Import')),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null || !context.mounted) return;
    String msg;
    try {
      msg = 'Imported ${DevValues.importJson(text)} values';
    } catch (_) {
      msg = 'That is not a müslic settings JSON';
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirm(BuildContext context, String title, String body,
      VoidCallback action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('OK')),
        ],
      ),
    );
    if (ok == true) action();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Chip(
            icon: Icons.ios_share_rounded,
            label: 'Export JSON',
            onTap: () => _export(context)),
        _Chip(
            icon: Icons.download_rounded,
            label: 'Import',
            onTap: () => _import(context)),
        _Chip(
          icon: Icons.restart_alt_rounded,
          label: 'Reset all',
          onTap: () => _confirm(context, 'Reset all?',
              'Every value goes back to the hardcoded default.',
              DevValues.resetAll),
        ),
        _Chip(
          icon: Icons.lock_outline_rounded,
          label: 'Turn off',
          onTap: () => _confirm(
              context,
              'Turn off developer settings?',
              'Your changed values stay in effect. Tap the logo five times '
                  'to come back.', () {
            DevValues.setUnlocked(false);
            Navigator.of(context).pop();
          }),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = Skin.of(context);
    return Material(
      color: skin.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: skin.ink),
              const SizedBox(width: 6),
              Text(label,
                  style: Txt.inter(14, FontWeight.w600, color: skin.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A collapsible group of sliders.
class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.title, required this.params});
  final String title;
  final List<DevParam> params;

  @override
  Widget build(BuildContext context) {
    final skin = Skin.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        // A Material (not a ColoredBox) so the tile's ink shows.
        child: Material(
          color: skin.surface,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ValueListenableBuilder<int>(
              valueListenable: DevValues.changes,
              builder: (context, _, __) {
                final changed = params.where((p) => p.changed).length;
                return ExpansionTile(
                  iconColor: skin.ink,
                  collapsedIconColor: skin.ink,
                  title: Text(title,
                      style: Txt.inter(16, FontWeight.w600, color: skin.ink)),
                  subtitle: Text(
                      changed == 0
                          ? '${params.length} values'
                          : '${params.length} values, $changed changed',
                      style: Txt.inter(12, FontWeight.w400,
                          color: Palette.muted)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
                  children: [for (final p in params) _ParamRow(param: p)],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ParamRow extends StatelessWidget {
  const _ParamRow({required this.param});
  final DevParam param;

  String _fmt(double v) =>
      '${v.toStringAsFixed(param.decimals)}${param.unit.isEmpty ? '' : ' ${param.unit}'}';

  @override
  Widget build(BuildContext context) {
    final skin = Skin.of(context);
    final p = param;
    final v = p.read().clamp(p.min, p.max).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(p.label,
                  style: Txt.inter(14, FontWeight.w500, color: skin.ink)),
            ),
            Text(_fmt(v),
                style: Txt.inter(13, FontWeight.w600,
                    color: p.changed ? skin.ink : Palette.muted)),
            SizedBox(
              width: 36,
              child: p.changed
                  ? IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      tooltip: 'Reset to ${_fmt(p.def)}',
                      color: skin.ink,
                      icon: const Icon(Icons.undo_rounded),
                      onPressed: () => DevValues.reset(p),
                    )
                  : null,
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            activeTrackColor: skin.ink,
            inactiveTrackColor: skin.ink.withValues(alpha: 0.15),
            thumbColor: skin.ink,
            overlayColor: skin.ink.withValues(alpha: 0.08),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            min: p.min,
            max: p.max,
            value: v,
            onChanged: (x) => DevValues.setValue(
                p, double.parse(x.toStringAsFixed(p.decimals))),
            onChangeEnd: (_) => DevValues.save(p),
          ),
        ),
      ],
    );
  }
}
