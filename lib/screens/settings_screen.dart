import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/artwork_cache.dart';
import '../state/library_controller.dart';
import '../state/settings_controller.dart';
import '../widgets/muslic_app_bar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final library = context.watch<LibraryController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text('Settings',
                style: Theme.of(context).textTheme.headlineSmall),
          ),
          _SectionHeader('Library order'),
          for (final (sort, label) in [
            (LibrarySort.name, 'Sort by name'),
            (LibrarySort.dateModified, 'Sort by date updated'),
          ])
            ListTile(
              title: Text(label),
              trailing: settings.sort == sort
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () =>
                  settings.setSort(sort, ascending: sort == LibrarySort.name),
            ),
          SwitchListTile(
            title: const Text('Reverse order'),
            subtitle: Text(settings.sort == LibrarySort.name
                ? 'Z to A instead of A to Z'
                : 'Oldest first instead of newest first'),
            // Date sort shows newest first by default, so "reversed" means
            // ascending there.
            value: settings.sort == LibrarySort.name
                ? !settings.sortAscending
                : settings.sortAscending,
            onChanged: (_) => settings.toggleSortDirection(),
          ),
          const Divider(height: 32),
          _SectionHeader('Music sources'),
          _FolderList(
            title: 'Only scan these folders',
            subtitle: settings.allowedFolders.isEmpty
                ? 'Empty means the whole device is scanned.'
                : null,
            folders: settings.allowedFolders,
            emptyHint: 'All folders included',
            onAdd: () => _pickFolder(context, settings.addAllowedFolder,
                library.discoveredFolders),
            onRemove: settings.removeAllowedFolder,
            accent: scheme.primary,
            icon: Icons.folder_special_rounded,
          ),
          const SizedBox(height: 12),
          _FolderList(
            title: 'Never scan these folders',
            folders: settings.bannedFolders,
            emptyHint: 'No folders banned',
            onAdd: () => _pickFolder(context, settings.addBannedFolder,
                library.discoveredFolders),
            onRemove: settings.removeBannedFolder,
            accent: scheme.error,
            icon: Icons.block_rounded,
          ),
          SwitchListTile(
            title: const Text('Apply rules to subfolders'),
            subtitle: const Text(
                'A folder rule also covers everything nested inside it.'),
            value: settings.includeSubfolders,
            onChanged: settings.setIncludeSubfolders,
          ),
          SwitchListTile(
            title: const Text('Hide WhatsApp audio'),
            subtitle: const Text('Skips voice notes and forwarded clips.'),
            value: settings.hideWhatsAppAudio,
            onChanged: settings.setHideWhatsAppAudio,
          ),
          const Divider(height: 32),
          _SectionHeader('Track length'),
          _DurationTile(
            title: 'Minimum length',
            seconds: settings.minDurationSeconds,
            zeroLabel: 'No minimum',
            onChanged: settings.setMinDuration,
            presets: const [0, 30, 60, 120, 300],
          ),
          _DurationTile(
            title: 'Maximum length',
            seconds: settings.maxDurationSeconds,
            zeroLabel: 'No maximum',
            onChanged: settings.setMaxDuration,
            presets: const [0, 600, 1800, 3600],
          ),
          const Divider(height: 32),
          _SectionHeader('Playback'),
          SwitchListTile(
            title: const Text('Remember speed, pitch and boost'),
            subtitle: const Text(
                'Keep your equalizer panel settings between launches.'),
            value: settings.rememberPlaybackSettings,
            onChanged: settings.setRememberPlaybackSettings,
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.refresh_rounded),
            title: const Text('Rescan library'),
            subtitle: Text('${library.tracks.length} tracks with current filters'),
            onTap: () {
              library.scan();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Rescanning library')),
              );
            },
          ),
          const _ArtworkCacheTile(),
        ],
      ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFolder(BuildContext context,
      void Function(String) onPicked, List<String> discovered) async {
    // Offer folders that actually contain audio first; fall back to the
    // system folder picker for anything else.
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_folder_upload_rounded),
              title: const Text('Browse all folders'),
              onTap: () => Navigator.pop(context, '::browse::'),
            ),
            if (discovered.isNotEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('Folders with audio on this device'),
              ),
            for (final f in discovered)
              ListTile(
                dense: true,
                leading: const Icon(Icons.folder_rounded),
                title: Text(f.split('/').last),
                subtitle:
                    Text(f, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(context, f),
              ),
          ],
        ),
      ),
    );

    if (choice == null) return;
    if (choice == '::browse::') {
      final dir = await FilePicker.platform.getDirectoryPath();
      if (dir != null) onPicked(dir);
    } else {
      onPicked(choice);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.8)),
    );
  }
}

class _FolderList extends StatelessWidget {
  const _FolderList({
    required this.title,
    required this.folders,
    required this.emptyHint,
    required this.onAdd,
    required this.onRemove,
    required this.accent,
    required this.icon,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<String> folders;
  final String emptyHint;
  final VoidCallback onAdd;
  final void Function(String) onRemove;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.titleSmall)),
                IconButton(
                  tooltip: 'Add folder',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: onAdd,
                ),
              ],
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            if (folders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(emptyHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant)),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final f in folders)
                    InputChip(
                      label: Text(f.split('/').last.isEmpty
                          ? f
                          : f.split('/').last),
                      tooltip: f,
                      onDeleted: () => onRemove(f),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DurationTile extends StatelessWidget {
  const _DurationTile({
    required this.title,
    required this.seconds,
    required this.zeroLabel,
    required this.onChanged,
    required this.presets,
  });

  final String title;
  final int seconds;
  final String zeroLabel;
  final void Function(int) onChanged;
  final List<int> presets;

  String _label(int s) {
    if (s == 0) return zeroLabel;
    if (s < 60) return '$s s';
    if (s < 3600) return '${(s / 60).toStringAsFixed(s % 60 == 0 ? 0 : 1)} min';
    return '${(s / 3600).toStringAsFixed(1)} h';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(
          spacing: 8,
          children: [
            for (final p in presets)
              ChoiceChip(
                label: Text(_label(p)),
                selected: seconds == p,
                onSelected: (_) => onChanged(p),
                visualDensity: VisualDensity.compact,
              ),
            ActionChip(
              label: const Text('Custom'),
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                final ctrl =
                    TextEditingController(text: seconds.toString());
                final v = await showDialog<int>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(title),
                    content: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          suffixText: 'seconds',
                          helperText: '0 disables the limit'),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(
                              context, int.tryParse(ctrl.text) ?? 0),
                          child: const Text('Set')),
                    ],
                  ),
                );
                if (v != null) onChanged(v);
              },
            ),
          ],
        ),
      ),
      trailing: Text(_label(seconds),
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}


/// Shows background blur progress and lets the user rebuild the cache.
class _ArtworkCacheTile extends StatelessWidget {
  const _ArtworkCacheTile();

  @override
  Widget build(BuildContext context) {
    final cache = context.read<ArtworkCache>();
    return ValueListenableBuilder<int>(
      valueListenable: cache.pending,
      builder: (context, pending, _) => ListTile(
        leading: const Icon(Icons.image_outlined),
        title: const Text('Rebuild artwork cache'),
        subtitle: Text(pending > 0
            ? 'Preparing backgrounds: $pending songs left'
            : 'All album art and blurred backgrounds are ready.'),
        onTap: () async {
          final library = context.read<LibraryController>();
          final messenger = ScaffoldMessenger.of(context);
          await cache.clear();
          await library.scan();
          messenger.showSnackBar(
            const SnackBar(content: Text('Rebuilding artwork cache')),
          );
        },
      ),
    );
  }
}
