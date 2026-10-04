import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../debug/ui_tuning.dart';
import '../state/library_controller.dart';
import '../state/player_controller.dart';
import '../ui/design.dart';
import '../widgets/muslic_app_bar.dart';
import '../widgets/player_shell.dart';
import '../widgets/song_carousel.dart';
import 'settings_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expansion =
      AnimationController(vsync: this, duration: PlayerMotion.expand);
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UiAssets.precacheAll(context);
      context.read<LibraryController>().scan();
    });
  }

  @override
  void dispose() {
    _expansion.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    final library = context.read<LibraryController>();
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchCtrl.clear();
        library.setSearch('');
        _searchFocus.unfocus();
      } else {
        _searchFocus.requestFocus();
      }
    });
  }

  void _onSelect(int index) {
    final library = context.read<LibraryController>();
    final player = context.read<PlayerController>();
    final track = library.tracks[index];
    if (player.current?.id == track.id) {
      PlayerShell.open(_expansion);
    } else {
      player.playQueue(library.tracks, index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final hasPlayer =
        context.select<PlayerController, bool>((p) => p.current != null);
    final f = Fg.of(context);
    final pad = MediaQuery.paddingOf(context);
    final size = MediaQuery.sizeOf(context);
    final appBarBottom = MuslicAppBar.bottom(context);
    final miniTop = size.height - pad.bottom - f(54 + 186);

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Carousel (or a status message).
          Positioned.fill(
            child: library.status == LibraryStatus.ready &&
                    library.tracks.isNotEmpty
                ? SongCarousel(
                    tracks: library.tracks,
                    topBound: appBarBottom,
                    bottomBound: miniTop,
                    onSelect: _onSelect,
                  )
                : _Status(library: library, searching: _searching),
          ),

          // White fades at the top and bottom (Figma Gradient1/Gradient2).
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: pad.top + f(481 - MuslicAppBar.statusShift),
            child: const IgnorePointer(child: _Fade(fromTop: true)),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: pad.bottom + f(481),
            child: const IgnorePointer(child: _Fade(fromTop: false)),
          ),

          // Player: mini bar, expanding into the full card.
          if (hasPlayer)
            Positioned.fill(child: PlayerShell(expansion: _expansion)),

          // App bar on top of everything. Its icons fade while the player
          // is open; the logo stays.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: AnimatedBuilder(
              animation: _expansion,
              builder: (context, _) {
                final iconOpacity =
                    (1 - _expansion.value * 2).clamp(0.0, 1.0);
                return IgnorePointer(
                  ignoring: _expansion.value > 0.5,
                  child: MuslicAppBar(
                    leading: Opacity(
                      opacity: iconOpacity,
                      child: AppBarIcon(
                        asset: UiAssets.settings,
                        tooltip: 'Settings',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen()),
                        ),
                      ),
                    ),
                    trailing: Opacity(
                      opacity: iconOpacity,
                      child: _searching
                          ? AppBarGlyph(
                              icon: Icons.close_rounded,
                              tooltip: 'Close search',
                              onTap: _toggleSearch,
                            )
                          : AppBarIcon(
                              asset: UiAssets.search,
                              tooltip: 'Search',
                              onTap: _toggleSearch,
                            ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Search field, just under the app bar.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            left: f(60),
            right: f(60),
            top: _searching ? appBarBottom + f(10) : appBarBottom - f(40),
            child: IgnorePointer(
              ignoring: !_searching,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _searching ? 1 : 0,
                child: _SearchField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  onChanged: library.setSearch,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fade extends StatelessWidget {
  const _Fade({required this.fromTop});
  final bool fromTop;

  @override
  Widget build(BuildContext context) {
    // Figma: transparent to white, reaching solid white at 63.5%.
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: fromTop ? Alignment.bottomCenter : Alignment.topCenter,
          end: fromTop ? Alignment.topCenter : Alignment.bottomCenter,
          colors: const [Color(0x00FFFFFF), Colors.white],
          stops: const [0.0, 0.635],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(f(60)),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: Txt.inter(f(36), FontWeight.w400, color: Palette.ink),
        cursorColor: Palette.ink,
        decoration: InputDecoration(
          hintText: 'Search title, artist or album',
          hintStyle:
              Txt.inter(f(36), FontWeight.w400, color: Palette.muted),
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: f(48), vertical: f(30)),
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.library, required this.searching});
  final LibraryController library;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final f = Fg.of(context);
    void openSettings() => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));

    final (IconData? icon, String title, String body, String? action,
        VoidCallback? onAction) = switch (library.status) {
      LibraryStatus.idle || LibraryStatus.scanning => (null, '', '', null, null),
      LibraryStatus.noPermission => (
          Icons.lock_outline_rounded,
          'müslic needs access to your audio files',
          'Allow audio access to see your library. Nothing leaves your phone.',
          'Allow access',
          library.scan,
        ),
      LibraryStatus.empty => (
          Icons.library_music_outlined,
          'No songs found',
          'Add music to your phone, or loosen the folder and length rules in Settings.',
          'Scan again',
          library.scan,
        ),
      LibraryStatus.error => (
          Icons.error_outline_rounded,
          'Scan failed',
          library.errorMessage ?? 'The media library could not be read.',
          'Try again',
          library.scan,
        ),
      LibraryStatus.ready => searching
          ? (
              Icons.search_off_rounded,
              'No matches',
              'No title, artist or album matches your search.',
              null,
              null,
            )
          : (
              Icons.filter_alt_off_rounded,
              'Every song is filtered out',
              'Your folder or length rules hide all songs. Change them in Settings.',
              'Open settings',
              openSettings,
            ),
    };

    if (icon == null) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child:
              CircularProgressIndicator(strokeWidth: 2.5, color: Palette.ink),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: f(120)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: f(150), color: Palette.ink),
          SizedBox(height: f(40)),
          Text(title,
              textAlign: TextAlign.center,
              style: Txt.inter(f(52), FontWeight.w700, color: Palette.ink)),
          SizedBox(height: f(20)),
          Text(body,
              textAlign: TextAlign.center,
              style: Txt.inter(f(36), FontWeight.w400, color: Palette.muted)),
          if (action != null) ...[
            SizedBox(height: f(60)),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Palette.ink,
                padding: EdgeInsets.symmetric(
                    horizontal: f(60), vertical: f(30)),
              ),
              onPressed: onAction,
              child: Text(action, style: Txt.inter(f(36), FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }
}
