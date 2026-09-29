import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/library_controller.dart';
import '../state/player_controller.dart';
import '../state/settings_controller.dart';
import '../widgets/artwork.dart';
import '../widgets/mini_player.dart';
import 'settings_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryController>().scan();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final settings = context.watch<SettingsController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              titleSpacing: 20,
              title: _searching
                  ? TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search title, artist, album',
                        border: InputBorder.none,
                      ),
                      onChanged: library.setSearch,
                    )
                  : Text('müslic',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: scheme.primary)),
              actions: [
                IconButton(
                  tooltip: _searching ? 'Close search' : 'Search',
                  icon: Icon(
                      _searching ? Icons.close_rounded : Icons.search_rounded),
                  onPressed: () {
                    setState(() {
                      if (_searching) {
                        _searchCtrl.clear();
                        library.setSearch('');
                      }
                      _searching = !_searching;
                    });
                  },
                ),
                _SortMenu(settings: settings),
                IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const SettingsScreen()),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            if (library.status == LibraryStatus.ready)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '${library.tracks.length} tracks',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
            ..._body(context, library, settings),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  List<Widget> _body(BuildContext context, LibraryController library,
      SettingsController settings) {
    switch (library.status) {
      case LibraryStatus.idle:
      case LibraryStatus.scanning:
        return const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        ];
      case LibraryStatus.noPermission:
        return [
          _message(
            context,
            icon: Icons.lock_outline_rounded,
            title: 'müslic needs access to your audio files',
            body:
                'Grant the audio permission to scan your library. Nothing leaves your device.',
            action: FilledButton(
              onPressed: library.scan,
              child: const Text('Grant access'),
            ),
          )
        ];
      case LibraryStatus.empty:
        return [
          _message(
            context,
            icon: Icons.library_music_outlined,
            title: 'No tracks found',
            body:
                'No audio matched your filters. Loosen the folder or length rules in settings, or add music to your device.',
            action: OutlinedButton(
              onPressed: library.scan,
              child: const Text('Rescan'),
            ),
          )
        ];
      case LibraryStatus.error:
        return [
          _message(
            context,
            icon: Icons.error_outline_rounded,
            title: 'Scan failed',
            body: library.errorMessage ?? 'Unknown error.',
            action: FilledButton(
                onPressed: library.scan, child: const Text('Try again')),
          )
        ];
      case LibraryStatus.ready:
        if (library.tracks.isEmpty) {
          return [
            _message(
              context,
              icon: Icons.filter_alt_off_rounded,
              title: 'Everything got filtered out',
              body:
                  'Your folder or length rules hide every track. Adjust them in settings or clear the search.',
              action: OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen())),
                child: const Text('Open settings'),
              ),
            )
          ];
        }
        return [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: settings.gridColumns,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: settings.gridColumns == 1 ? 3.4 : 0.78,
              ),
              delegate: SliverChildBuilderDelegate(
                childCount: library.tracks.length,
                (context, i) => _TrackCard(index: i),
              ),
            ),
          ),
        ];
    }
  }

  Widget _message(BuildContext context,
      {required IconData icon,
      required String title,
      required String body,
      required Widget action}) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            action,
          ],
        ),
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.settings});
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Sort',
      icon: const Icon(Icons.sort_rounded),
      onSelected: (v) {
        switch (v) {
          case 'name':
            settings.setSort(LibrarySort.name);
          case 'date':
            settings.setSort(LibrarySort.dateModified);
          case 'dir':
            settings.toggleSortDirection();
          case 'cols1':
            settings.setGridColumns(1);
          case 'cols2':
            settings.setGridColumns(2);
          case 'cols3':
            settings.setGridColumns(3);
        }
      },
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: 'name',
          checked: settings.sort == LibrarySort.name,
          child: const Text('Sort by name'),
        ),
        CheckedPopupMenuItem(
          value: 'date',
          checked: settings.sort == LibrarySort.dateModified,
          child: const Text('Sort by date updated'),
        ),
        PopupMenuItem(
          value: 'dir',
          child: Row(children: [
            Icon(settings.sortAscending
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded),
            const SizedBox(width: 8),
            Text(settings.sortAscending ? 'Ascending' : 'Descending'),
          ]),
        ),
        const PopupMenuDivider(),
        CheckedPopupMenuItem(
            value: 'cols1',
            checked: settings.gridColumns == 1,
            child: const Text('List view')),
        CheckedPopupMenuItem(
            value: 'cols2',
            checked: settings.gridColumns == 2,
            child: const Text('Grid · 2 columns')),
        CheckedPopupMenuItem(
            value: 'cols3',
            checked: settings.gridColumns == 3,
            child: const Text('Grid · 3 columns')),
      ],
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final library = context.read<LibraryController>();
    final player = context.watch<PlayerController>();
    final settings = context.read<SettingsController>();
    final track = library.tracks[index];
    final isCurrent = player.current?.id == track.id;
    final scheme = Theme.of(context).colorScheme;
    final listMode = settings.gridColumns == 1;

    final card = Material(
      color: isCurrent ? scheme.primaryContainer.withValues(alpha: 0.35) : scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context
            .read<PlayerController>()
            .playQueue(library.tracks, index),
        child: listMode ? _listChild(context, track, scheme) : _gridChild(context, track, scheme),
      ),
    );
    return card;
  }

  Widget _gridChild(BuildContext context, track, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => Stack(
              fit: StackFit.expand,
              children: [
                TrackArtwork(
                    trackId: track.id,
                    size: c.maxWidth,
                    borderRadius: 0),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(track.durationLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
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
              const SizedBox(height: 2),
              Text(track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _listChild(BuildContext context, track, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          TrackArtwork(trackId: track.id, size: 56, borderRadius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text('${track.artist} · ${track.album}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(track.durationLabel,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
