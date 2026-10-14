import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../services/artwork_cache.dart';
import '../state/library_controller.dart';
import '../state/settings_controller.dart';
import '../ui/design.dart';
import '../ui/skin.dart';
import '../widgets/blend_image.dart';
import '../widgets/muslic_app_bar.dart';

/// Settings: grouped cards in the app's monochrome style, with a wide-set
/// Kumbh Sans title echoing the library's vertical song title. Folder rules
/// and length limits open in bottom sheets to keep this page short.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final library = context.watch<LibraryController>();
    final skin = Skin.of(context);
    final f = Fg.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    String folderSummary(List<String> folders, String none) => folders.isEmpty
        ? none
        : folders.length == 1
            ? folders.first.split('/').last
            : '${folders.length} folders';

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
              padding: EdgeInsets.fromLTRB(20, 8, 20, 32 + bottom),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 22),
                  child: Text('SETTINGS',
                      style: Txt.kumbh(f(64),
                          color: skin.ink, letterSpacing: f(18))),
                ),
                _Group(label: 'Appearance', children: [
                  _Row(
                    title: 'Theme',
                    trailing: _Segmented<AppTheme>(
                      value: settings.theme,
                      options: const [
                        (AppTheme.light, 'Light'),
                        (AppTheme.dark, 'Dark'),
                      ],
                      onChanged: settings.setTheme,
                    ),
                  ),
                  _SwitchRow(
                    title: 'Scroll sound',
                    subtitle: 'A soft click as songs pass in the carousel',
                    value: settings.scrollSound,
                    onChanged: settings.setScrollSound,
                  ),
                ]),
                _Group(label: 'Library', children: [
                  _Row(
                    title: 'Sort by',
                    below: _Segmented<LibrarySort>(
                      expand: true,
                      value: settings.sort,
                      options: const [
                        (LibrarySort.artist, 'Artist'),
                        (LibrarySort.name, 'Song'),
                        (LibrarySort.dateModified, 'Date'),
                      ],
                      onChanged: (s) => settings.setSort(s, ascending: true),
                    ),
                  ),
                  _SwitchRow(
                    title: 'Reverse order',
                    subtitle: switch (settings.sort) {
                      LibrarySort.artist => 'Artists from Z to A',
                      LibrarySort.name => 'Songs from Z to A',
                      LibrarySort.dateModified => 'Oldest files first',
                    },
                    value: !settings.sortAscending,
                    onChanged: (_) => settings.toggleSortDirection(),
                  ),
                  _SwitchRow(
                    title: 'Tidy song names',
                    subtitle: 'Hide "(Official Video)" and similar, and split '
                        '"Artist - Song" titles. Files are not changed.',
                    value: settings.tidyTitles,
                    onChanged: settings.setTidyTitles,
                  ),
                ]),
                _Group(label: 'Music sources', children: [
                  _Row(
                    title: 'Only scan',
                    value: folderSummary(settings.allowedFolders, 'All folders'),
                    onTap: () => _folderSheet(
                      context,
                      title: 'Only scan these folders',
                      hint: 'Leave empty to scan the whole phone.',
                      folders: (s) => s.allowedFolders,
                      add: settings.addAllowedFolder,
                      remove: settings.removeAllowedFolder,
                      discovered: library.discoveredFolders,
                    ),
                  ),
                  _Row(
                    title: 'Never scan',
                    value: folderSummary(settings.bannedFolders, 'None'),
                    onTap: () => _folderSheet(
                      context,
                      title: 'Never scan these folders',
                      hint: 'Songs in these folders are hidden.',
                      folders: (s) => s.bannedFolders,
                      add: settings.addBannedFolder,
                      remove: settings.removeBannedFolder,
                      discovered: library.discoveredFolders,
                    ),
                  ),
                  _SwitchRow(
                    title: 'Include subfolders',
                    subtitle: 'Folder rules also cover folders inside them',
                    value: settings.includeSubfolders,
                    onChanged: settings.setIncludeSubfolders,
                  ),
                  _SwitchRow(
                    title: 'Hide WhatsApp audio',
                    subtitle: 'Skip voice notes and forwarded clips',
                    value: settings.hideWhatsAppAudio,
                    onChanged: settings.setHideWhatsAppAudio,
                  ),
                  _Row(
                    title: 'Shortest song',
                    value: _duration(settings.minDurationSeconds, 'Any'),
                    onTap: () => _durationSheet(
                      context,
                      title: 'Hide songs shorter than',
                      zeroLabel: 'Show all',
                      current: settings.minDurationSeconds,
                      presets: const [0, 30, 60, 120, 300],
                      onChanged: settings.setMinDuration,
                    ),
                  ),
                  _Row(
                    title: 'Longest song',
                    value: _duration(settings.maxDurationSeconds, 'Any'),
                    onTap: () => _durationSheet(
                      context,
                      title: 'Hide songs longer than',
                      zeroLabel: 'Show all',
                      current: settings.maxDurationSeconds,
                      presets: const [0, 600, 1800, 3600],
                      onChanged: settings.setMaxDuration,
                    ),
                  ),
                ]),
                _Group(label: 'Playback', children: [
                  _SwitchRow(
                    title: 'Remember last song',
                    subtitle: 'Reopen on the song you were playing, '
                        'at the same spot',
                    value: settings.rememberLastSong,
                    onChanged: settings.setRememberLastSong,
                  ),
                  _SwitchRow(
                    title: 'Remember sound settings',
                    subtitle: 'Speed, pitch, boost, reverb, echo and ambient',
                    value: settings.rememberPlaybackSettings,
                    onChanged: settings.setRememberPlaybackSettings,
                  ),
                  const _NotificationRow(),
                  const _Row(
                    title: 'Background playback',
                    subtitle: 'If music stops with the screen off, set '
                        'battery use to "Unrestricted"',
                    onTap: openAppSettings,
                  ),
                ]),
                _Group(label: 'Storage', children: [
                  _Row(
                    title: 'Rescan library',
                    value: '${library.tracks.length} songs',
                    onTap: () {
                      library.scan();
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Rescanning library')));
                    },
                  ),
                  const _ArtworkRow(),
                ]),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Text('müslic by dot Studios',
                        style: Txt.inter(13, FontWeight.w500,
                            color: Palette.muted)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _duration(int s, String zero) {
    if (s == 0) return zero;
    if (s < 60) return '$s sec';
    if (s < 3600) {
      final m = s / 60;
      return '${m.toStringAsFixed(s % 60 == 0 ? 0 : 1)} min';
    }
    final h = s / 3600;
    return '${h.toStringAsFixed(s % 3600 == 0 ? 0 : 1)} h';
  }

  // ---------------------------------------------------------------------
  // Sheets
  // ---------------------------------------------------------------------

  static Future<T?> _sheet<T>(BuildContext context, WidgetBuilder builder) {
    final skin = Skin.of(context);
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: skin.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
          child: builder(ctx),
        ),
      ),
    );
  }

  static void _folderSheet(
    BuildContext context, {
    required String title,
    required String hint,
    required List<String> Function(SettingsController) folders,
    required void Function(String) add,
    required void Function(String) remove,
    required List<String> discovered,
  }) {
    _sheet<void>(context, (ctx) {
      final skin = Skin.of(ctx);
      final list = folders(ctx.watch<SettingsController>());
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        children: [
          _SheetTitle(title: title, hint: hint),
          if (list.isNotEmpty)
            _Card(children: [
              for (final path in list)
                _Row(
                  title: path.split('/').last.isEmpty
                      ? path
                      : path.split('/').last,
                  subtitle: path,
                  trailing: _IconAction(
                    icon: Icons.close_rounded,
                    tooltip: 'Remove',
                    onTap: () => remove(path),
                  ),
                ),
            ]),
          const SizedBox(height: 12),
          _WideButton(
            label: 'Add folder',
            icon: Icons.add_rounded,
            color: skin.ink,
            onTap: () => _pickFolder(ctx, add, discovered),
          ),
        ],
      );
    });
  }

  static Future<void> _pickFolder(BuildContext context,
      void Function(String) onPicked, List<String> discovered) async {
    // Folders that actually contain audio first; the system folder picker
    // for anything else.
    final choice = await _sheet<String>(context, (ctx) {
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        children: [
          const _SheetTitle(
              title: 'Choose a folder', hint: 'Folders with music on this phone'),
          _Card(children: [
            _Row(
              title: 'Browse all folders',
              onTap: () => Navigator.pop(ctx, '::browse::'),
            ),
            for (final f in discovered)
              _Row(
                title: f.split('/').last,
                subtitle: f,
                onTap: () => Navigator.pop(ctx, f),
              ),
          ]),
        ],
      );
    });
    if (choice == null) return;
    if (choice == '::browse::') {
      final dir = await FilePicker.platform.getDirectoryPath();
      if (dir != null) onPicked(dir);
    } else {
      onPicked(choice);
    }
  }

  static void _durationSheet(
    BuildContext context, {
    required String title,
    required String zeroLabel,
    required int current,
    required List<int> presets,
    required void Function(int) onChanged,
  }) {
    _sheet<void>(context, (ctx) {
      final skin = Skin.of(ctx);
      void pick(int v) {
        onChanged(v);
        Navigator.pop(ctx);
      }

      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        children: [
          _SheetTitle(title: title),
          _Card(children: [
            for (final p in presets)
              _Row(
                title: p == 0 ? zeroLabel : _duration(p, zeroLabel),
                trailing: p == current
                    ? Icon(Icons.check_rounded, color: skin.ink)
                    : null,
                onTap: () => pick(p),
              ),
            _Row(
              title: 'Custom',
              value: presets.contains(current) ? null : _duration(current, ''),
              onTap: () async {
                final v = await _customSeconds(ctx, title, current);
                if (v != null) pick(v);
              },
            ),
          ]),
        ],
      );
    });
  }

  static Future<int?> _customSeconds(
      BuildContext context, String title, int current) {
    final ctrl = TextEditingController(text: current == 0 ? '' : '$current');
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              suffixText: 'seconds', helperText: '0 turns the limit off'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, int.tryParse(ctrl.text.trim()) ?? 0),
              child: const Text('Set')),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Building blocks
// -----------------------------------------------------------------------

/// A labelled card of rows.
class _Group extends StatelessWidget {
  const _Group({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            child: Text(label.toUpperCase(),
                style: Txt.inter(12, FontWeight.w600, color: Palette.muted)
                    .copyWith(letterSpacing: 1.4)),
          ),
          _Card(children: children),
        ],
      ),
    );
  }
}

/// Rounded surface with hairlines between rows.
class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final skin = Skin.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(
        color: skin.surface,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 18),
                  child: Container(height: 0.8, color: skin.hairline),
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// One setting: title, optional subtitle, optional value text or trailing
/// control, optional full-width control [below]. Tappable rows show a
/// chevron.
class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.below,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final Widget? below;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final skin = Skin.of(context);
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Txt.inter(16, FontWeight.w500, color: skin.ink)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!,
                          style: Txt.inter(13, FontWeight.w400,
                                  color: Palette.muted)
                              .copyWith(height: 1.3)),
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: Txt.inter(15, FontWeight.w400,
                          color: Palette.muted)),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ] else if (onTap != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.chevron_right_rounded,
                      color: Palette.muted, size: 22),
                ),
            ],
          ),
          if (below != null) ...[const SizedBox(height: 12), below!],
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final skin = Skin.of(context);
    return _Row(
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? skin.background
                : skin.ink.withValues(alpha: 0.45)),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? skin.ink
                : skin.ink.withValues(alpha: 0.08)),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}

/// Pill segmented control with a sliding thumb.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.value,
    required this.options,
    required this.onChanged,
    this.expand = false,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final skin = Skin.of(context);
    final index = options.indexWhere((o) => o.$1 == value).clamp(0, 99);
    const height = 38.0;

    Widget control(double width) {
      final segment = (width - 6) / options.length;
      return Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: skin.ink.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              left: segment * index,
              top: 0,
              bottom: 0,
              width: segment,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: skin.dark ? const Color(0xFF2C2C30) : Colors.white,
                  borderRadius: BorderRadius.circular(height / 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                for (final (v, label) in options)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(v),
                      child: Center(
                        child: Text(label,
                            style: Txt.inter(
                                14,
                                v == value ? FontWeight.w600 : FontWeight.w500,
                                color: v == value
                                    ? skin.ink
                                    : skin.ink.withValues(alpha: 0.55))),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    if (!expand) return control(76.0 * options.length);
    return LayoutBuilder(builder: (context, c) => control(c.maxWidth));
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.title, this.hint});
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final skin = Skin.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Txt.inter(20, FontWeight.w700, color: skin.ink)),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!,
                style: Txt.inter(14, FontWeight.w400, color: Palette.muted)),
          ],
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction(
      {required this.icon, required this.onTap, required this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Bouncy(
      onTap: onTap,
      semanticLabel: tooltip,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 20, color: Palette.muted),
      ),
    );
  }
}

class _WideButton extends StatelessWidget {
  const _WideButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = Skin.of(context);
    return Bouncy(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: skin.background, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: Txt.inter(15, FontWeight.w600, color: skin.background)),
          ],
        ),
      ),
    );
  }
}

/// Artwork cache: shows background progress; tap rebuilds it.
class _ArtworkRow extends StatelessWidget {
  const _ArtworkRow();

  @override
  Widget build(BuildContext context) {
    final cache = context.read<ArtworkCache>();
    return ValueListenableBuilder<int>(
      valueListenable: cache.pending,
      builder: (context, pending, _) => _Row(
        title: 'Rebuild artwork',
        subtitle: pending > 0
            ? 'Preparing backgrounds, $pending songs left'
            : 'Album art and backgrounds are up to date',
        onTap: () async {
          final library = context.read<LibraryController>();
          final messenger = ScaffoldMessenger.of(context);
          await cache.clear();
          await library.scan();
          messenger.showSnackBar(
              const SnackBar(content: Text('Rebuilding artwork')));
        },
      ),
    );
  }
}

/// Notification permission: lock screen and notification shade controls.
class _NotificationRow extends StatefulWidget {
  const _NotificationRow();

  @override
  State<_NotificationRow> createState() => _NotificationRowState();
}

class _NotificationRowState extends State<_NotificationRow>
    with WidgetsBindingObserver {
  PermissionStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-check when returning from the system settings screen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final s = await Permission.notification.status;
      if (mounted) setState(() => _status = s);
    } catch (_) {}
  }

  Future<void> _fix() async {
    final s = await Permission.notification.request();
    if (!s.isGranted) await openAppSettings();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final granted = _status?.isGranted ?? true;
    return _Row(
      title: 'Lock screen controls',
      subtitle: granted
          ? 'Player shows on the lock screen and in notifications'
          : 'Off. Tap to allow notifications.',
      value: granted ? 'On' : null,
      onTap: granted ? null : _fix,
    );
  }
}
