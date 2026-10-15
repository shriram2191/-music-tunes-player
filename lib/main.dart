import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_plus/share_plus.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'ads.dart';
import 'controller.dart';
import 'regions.dart';

const bg = Color(0xFF050609);
const panel = Color(0xFF11131A);
const violet = Color(0xFF9B7BFF);
const cyan = Color(0xFF55E6D0);

final MusicController music = MusicController();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.music_tunes.playback',
    androidNotificationChannelName: 'Music Tunes playback',
    androidNotificationOngoing: true,
  );
  runApp(const MusicTunesApp());
  unawaited(MobileAds.instance.initialize());
  try {
    await music.init();
  } catch (e, s) {
    debugPrint('MusicTunes init failed: $e\n$s');
  }
}

class MusicTunesApp extends StatelessWidget {
  const MusicTunesApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Music Tunes',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: bg,
          colorScheme: const ColorScheme.dark(primary: violet, secondary: cyan, surface: panel),
          useMaterial3: true,
        ),
        home: const MusicHome(),
      );
}

void _snack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

Future<void> _pickFiles(BuildContext context) async {
  final result = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: true);
  if (result == null) return;
  music.addToLibrary(result.files.where((f) => f.path != null).map(
      (f) => Track(title: f.name.replaceAll(RegExp(r'\.[^.]+$'), ''), path: f.path!)));
}

Future<void> _play(BuildContext context, List<Track> list, int index) async {
  final err = await music.playQueue(list, index);
  if (err != null && context.mounted) _snack(context, err);
}

// ===================================================== Home shell
class MusicHome extends StatefulWidget {
  const MusicHome({super.key});
  @override
  State<MusicHome> createState() => _MusicHomeState();
}

class _MusicHomeState extends State<MusicHome> {
  int _tab = 0;
  StreamSubscription<String>? _errorSub;

  @override
  void initState() {
    super.initState();
    _errorSub = music.errors.listen((msg) {
      if (mounted) _snack(context, msg);
    });
  }

  @override
  void dispose() {
    _errorSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeTab(onGoto: (i) => setState(() => _tab = i)),
      const LibraryTab(),
      const OnlineTab(),
      const PlaylistsTab(),
      const LikedTab(),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [violet, cyan]), borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.graphic_eq_rounded, color: Colors.black, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('MUSIC TUNES', style: TextStyle(letterSpacing: 2.6, fontWeight: FontWeight.w900, fontSize: 17)),
              ),
              IconButton(
                tooltip: 'Equalizer & sleep timer',
                icon: const Icon(Icons.tune_rounded, color: cyan),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SoundScreen())),
              ),
              IconButton(
                tooltip: 'Add music files',
                icon: const Icon(Icons.add_circle_outline, color: violet, size: 26),
                onPressed: () => _pickFiles(context),
              ),
            ]),
          ),
          Expanded(child: pages[_tab]),
          if (_tab == 2) const BannerAdWidget(),
          const MiniPlayer(),
          NavigationBar(
            backgroundColor: const Color(0xFF0B0C10),
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music), label: 'Library'),
              NavigationDestination(icon: Icon(Icons.cloud_outlined), selectedIcon: Icon(Icons.cloud), label: 'Online'),
              NavigationDestination(icon: Icon(Icons.queue_music_outlined), selectedIcon: Icon(Icons.queue_music), label: 'Playlists'),
              NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Liked'),
            ],
          ),
        ]),
      ),
    );
  }
}

// ===================================================== Shared widgets
class Artwork extends StatelessWidget {
  const Artwork(this.track, {super.key, this.size = 48, this.radius = 12});
  final Track? track;
  final double size;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size, height: size,
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF30234D), Color(0xFF163238)])),
      child: Icon(Icons.music_note_rounded, color: cyan, size: size * .5),
    );
    final img = track?.image ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: img.isEmpty
          ? placeholder
          : Image.network(img, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder),
    );
  }
}

Future<void> showAddToPlaylist(BuildContext context, Track t) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: panel,
    builder: (ctx) => ListenableBuilder(
      listenable: music,
      builder: (_, __) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Add to playlist', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
          ListTile(
            leading: const Icon(Icons.add, color: cyan),
            title: const Text('New playlist'),
            onTap: () async {
              final name = await askName(ctx, 'New playlist');
              if (name != null) {
                music.addToPlaylist(music.createPlaylist(name), t);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
          ),
          for (final p in music.playlists)
            ListTile(
              leading: const Icon(Icons.queue_music, color: violet),
              title: Text(p.name),
              subtitle: Text('${p.tracks.length} tracks'),
              onTap: () {
                music.addToPlaylist(p, t);
                Navigator.pop(ctx);
              },
            ),
        ]),
      ),
    ),
  );
}

Future<String?> askName(BuildContext context, String title) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: panel,
      title: Text(title),
      content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Name')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Create')),
      ],
    ),
  );
}

class TrackTile extends StatelessWidget {
  const TrackTile({super.key, required this.tracks, required this.index, this.extraMenu, this.onRemove});
  final List<Track> tracks;
  final int index;
  final String? extraMenu;
  final VoidCallback? onRemove;
  @override
  Widget build(BuildContext context) {
    final t = tracks[index];
    final isCurrent = music.current?.path == t.path;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: () => _play(context, tracks, index),
        leading: Artwork(t),
        title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w600, color: isCurrent ? cyan : null)),
        subtitle: Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: Icon(music.isFav(t) ? Icons.favorite : Icons.favorite_border,
                color: music.isFav(t) ? violet : Colors.white38),
            onPressed: () => music.toggleFav(t),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white54),
            color: panel,
            onSelected: (v) async {
              if (v == 'share') {
                await Share.share('\ud83c\udfb5 ${t.title} \u2014 ${t.artist}\nListening on Music Tunes \ud83c\udfa7');
              }
              if (v == 'download') {
                if (music.isDownloaded(t)) {
                  music.removeDownload(t);
                } else {
                  final err = await music.downloadTrack(t);
                  if (context.mounted) _snack(context, err ?? 'Downloaded \u2014 plays offline now');
                }
              }
              if (v == 'playlist') showAddToPlaylist(context, t);
              if (v == 'remove') onRemove?.call();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'share', child: Text('Share')),
              if (t.isOnline)
                PopupMenuItem(
                    value: 'download',
                    child: Text(music.isDownloaded(t) ? 'Remove download' : 'Download')),
              const PopupMenuItem(value: 'playlist', child: Text('Add to playlist')),
              if (onRemove != null) PopupMenuItem(value: 'remove', child: Text(extraMenu ?? 'Remove')),
            ],
          ),
        ]),
      ),
    );
  }
}

Widget emptyState(IconData icon, String title, String sub) => Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 44, color: violet),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(sub, style: const TextStyle(color: Colors.white38), textAlign: TextAlign.center),
        ]),
      ),
    );

Widget sectionTitle(String t, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
      child: Row(children: [
        Expanded(child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        if (trailing != null) trailing,
      ]),
    );

// ===================================================== Home tab
class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.onGoto});
  final void Function(int) onGoto;

  Widget _hCards(BuildContext context, List<Track> list) => SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => _play(context, list, i),
            child: SizedBox(
              width: 104,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Artwork(list[i], size: 104, radius: 16),
                const SizedBox(height: 6),
                Text(list[i].title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text(list[i].artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.white38)),
              ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: music,
        builder: (context, _) {
          final hour = DateTime.now().hour;
          final greet = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';
          const prompts = [
            'What do you want to hear?',
            'Find your next favorite song.',
            'Press play. Feel everything.',
            'Your soundtrack starts here.',
          ];
          final hero = prompts[DateTime.now().day % prompts.length];
          return ListView(padding: const EdgeInsets.only(bottom: 12), children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF27203E), Color(0xFF111820), Color(0xFF101116)]),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(greet.toUpperCase(), style: const TextStyle(color: cyan, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(hero, style: const TextStyle(fontSize: 27, height: 1.1, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  Wrap(spacing: 10, runSpacing: 8, children: [
                    FilledButton.icon(
                      onPressed: music.library.isEmpty
                          ? () => _pickFiles(context)
                          : () async {
                              await music.playQueue(List.of(music.library), 0);
                              if (!music.player.shuffleModeEnabled) await music.toggleShuffle();
                            },
                      icon: Icon(music.library.isEmpty ? Icons.library_music_rounded : Icons.shuffle),
                      label: Text(music.library.isEmpty ? 'Add music' : 'Shuffle my music'),
                      style: FilledButton.styleFrom(backgroundColor: violet, foregroundColor: Colors.black),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => onGoto(2),
                      icon: const Icon(Icons.cloud_outlined, size: 18),
                      label: const Text('Stream online'),
                    ),
                  ]),
                ]),
              ),
            ),
            if (music.recent.isNotEmpty) ...[
              sectionTitle('Continue listening'),
              _hCards(context, music.recent),
            ],
            if (music.dailyMix.isNotEmpty) ...[
              sectionTitle('Made for you today'),
              _hCards(context, music.dailyMix),
            ],
            sectionTitle('Trending online', trailing: TextButton(onPressed: () => onGoto(2), child: const Text('SEE ALL'))),
            if (music.onlineLoading && music.onlineTracks.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (music.onlineTracks.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Connect to the internet to see online music.', style: TextStyle(color: Colors.white38)))
            else
              _hCards(context, music.onlineTracks),
            if (music.favourites.isNotEmpty) ...[
              sectionTitle('Your favourites', trailing: TextButton(onPressed: () => onGoto(4), child: const Text('SEE ALL'))),
              _hCards(context, music.favourites),
            ],
          ]);
        },
      );
}

// ===================================================== Library
class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});
  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  String _q = '';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: music,
        builder: (context, _) {
          final q = _q.toLowerCase();
          final list = q.isEmpty
              ? music.library
              : music.library.where((t) => t.title.toLowerCase().contains(q) || t.artist.toLowerCase().contains(q)).toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'Search your music',
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
                  filled: true, fillColor: panel,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? emptyState(Icons.headphones_rounded, 'Your library is ready for your music',
                      'Tap + at the top to choose audio files from your phone.')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      itemCount: list.length,
                      itemBuilder: (_, i) => TrackTile(
                          tracks: list, index: i, extraMenu: 'Remove from library', onRemove: () => music.removeFromLibrary(list[i])),
                    ),
            ),
          ]);
        },
      );
}

// ===================================================== Online
class OnlineTab extends StatefulWidget {
  const OnlineTab({super.key});
  @override
  State<OnlineTab> createState() => _OnlineTabState();
}

class _OnlineTabState extends State<OnlineTab> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: music,
        builder: (context, _) {
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) {
                  music.onlineCategory = '';
                  music.searchOnline(v);
                },
                decoration: InputDecoration(
                  hintText: 'Search online tracks',
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
                  suffixIcon: IconButton(
                    tooltip: 'Country & language',
                    icon: Text(music.regionFlag, style: const TextStyle(fontSize: 20)),
                    onPressed: () => showRegionPicker(context),
                  ),
                  filled: true, fillColor: panel,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            for (final r in music.selectedRegions) ...[
              sectionTitle('${r.flag} ${r.country} \u00b7 ${r.language}'),
              SizedBox(
                height: 150,
                child: (music.regionalCharts[r.country]?.isEmpty ?? true)
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: music.regionalCharts[r.country]!.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) {
                          final list = music.regionalCharts[r.country]!;
                          final t = list[i];
                          return GestureDetector(
                            onTap: () => _play(context, list, i),
                            child: SizedBox(
                              width: 104,
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Artwork(t, size: 104, radius: 16),
                                const SizedBox(height: 6),
                                Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: Colors.white38)),
                              ]),
                            ),
                          );
                        },
                      ),
              ),
            ],
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final c in MusicController.categoryTerms.keys)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: music.onlineCategory == c,
                        selectedColor: violet,
                        backgroundColor: panel,
                        labelStyle: TextStyle(
                            color: music.onlineCategory == c ? Colors.black : Colors.white70, fontWeight: FontWeight.w600),
                        onSelected: (_) {
                          _search.clear();
                          music.loadOnline(c);
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: music.onlineLoading
                  ? const Center(child: CircularProgressIndicator())
                  : music.onlineTracks.isEmpty
                      ? Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.cloud_off, color: violet, size: 40),
                            const SizedBox(height: 10),
                            Text(music.onlineError ?? 'Nothing here yet', style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 10),
                            FilledButton(
                                onPressed: () => music.retryOnline(),
                                child: const Text('Try again')),
                          ]),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          itemCount: music.onlineTracks.length + 1,
                          itemBuilder: (_, i) => i == music.onlineTracks.length
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('Independent & openly licensed music. Commercial chart songs are not included.',
                                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white30, fontSize: 11)))
                              : TrackTile(tracks: music.onlineTracks, index: i),
                        ),
            ),
          ]);
        },
      );
}

// ===================================================== Playlists
class PlaylistsTab extends StatelessWidget {
  const PlaylistsTab({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: music,
        builder: (context, _) => Column(children: [
          sectionTitle('Playlists',
              trailing: TextButton.icon(
                onPressed: () async {
                  final n = await askName(context, 'New playlist');
                  if (n != null) music.createPlaylist(n);
                },
                icon: const Icon(Icons.add),
                label: const Text('NEW'),
              )),
          Expanded(
            child: music.playlists.isEmpty
                ? emptyState(Icons.queue_music, 'No playlists yet', 'Create one, then add songs from the ⋮ menu on any track.')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    itemCount: music.playlists.length,
                    itemBuilder: (_, i) {
                      final p = music.playlists[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          leading: p.tracks.isEmpty ? const Artwork(null) : Artwork(p.tracks.first),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${p.tracks.length} tracks', style: const TextStyle(color: Colors.white54)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlaylistScreen(playlist: p))),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      );
}

class PlaylistScreen extends StatelessWidget {
  const PlaylistScreen({super.key, required this.playlist});
  final Playlist playlist;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: music,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            backgroundColor: bg,
            title: Text(playlist.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  music.deletePlaylist(playlist);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          floatingActionButton: playlist.tracks.isEmpty
              ? null
              : FloatingActionButton(
                  backgroundColor: violet,
                  foregroundColor: Colors.black,
                  onPressed: () => _play(context, List.of(playlist.tracks), 0),
                  child: const Icon(Icons.play_arrow_rounded, size: 32),
                ),
          body: playlist.tracks.isEmpty
              ? emptyState(Icons.queue_music, 'This playlist is empty', 'Use the ⋮ menu on any song to add it here.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: playlist.tracks.length,
                  itemBuilder: (_, i) => TrackTile(
                      tracks: playlist.tracks, index: i, extraMenu: 'Remove from playlist',
                      onRemove: () => music.removeFromPlaylist(playlist, playlist.tracks[i])),
                ),
          bottomNavigationBar: const MiniPlayer(),
        ),
      );
}

// ===================================================== Liked
class LikedTab extends StatelessWidget {
  const LikedTab({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: music,
        builder: (context, _) => Column(children: [
          sectionTitle('Favourites'),
          Expanded(
            child: music.favourites.isEmpty
                ? emptyState(Icons.favorite_border, 'Your favourites will live here', 'Tap the heart on any song, local or online.')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    itemCount: music.favourites.length,
                    itemBuilder: (_, i) => TrackTile(tracks: music.favourites, index: i),
                  ),
          ),
        ]),
      );
}

// ===================================================== Mini + full player
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: music,
        builder: (context, _) {
          final t = music.current;
          if (t == null) return const SizedBox.shrink();
          return GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: bg,
              builder: (_) => const NowPlaying(),
            ),
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: const Color(0xFF171922), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)),
              child: Row(children: [
                Artwork(t, size: 42),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ]),
                ),
                IconButton(icon: const Icon(Icons.skip_previous_rounded), onPressed: music.player.seekToPrevious),
                StreamBuilder<PlayerState>(
                  stream: music.player.playerStateStream,
                  builder: (_, snap) {
                    final playing = snap.data?.playing ?? false;
                    return IconButton(
                      iconSize: 36,
                      color: violet,
                      icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill),
                      onPressed: () => playing ? music.player.pause() : music.player.play(),
                    );
                  },
                ),
                IconButton(icon: const Icon(Icons.skip_next_rounded), onPressed: music.player.seekToNext),
              ]),
            ),
          );
        },
      );
}

String _fmt(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:${m.padLeft(2, '0')}:$s' : '$m:$s';
}

class NowPlaying extends StatelessWidget {
  const NowPlaying({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: music,
        builder: (context, _) {
          final t = music.current;
          final p = music.player;
          if (t == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(children: [
              Row(children: [
                IconButton(icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32), onPressed: () => Navigator.pop(context)),
                const Expanded(
                    child: Text('NOW PLAYING', textAlign: TextAlign.center,
                        style: TextStyle(letterSpacing: 2, fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold))),
                IconButton(
                  icon: const Icon(Icons.tune_rounded, color: cyan),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SoundScreen())),
                ),
              ]),
              const Spacer(),
              Artwork(t, size: MediaQuery.of(context).size.width - 90, radius: 28),
              const Spacer(),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54)),
                  ]),
                ),
                IconButton(
                  icon: Icon(music.isFav(t) ? Icons.favorite : Icons.favorite_border, color: violet),
                  onPressed: () => music.toggleFav(t),
                ),
                IconButton(icon: const Icon(Icons.playlist_add, color: Colors.white70), onPressed: () => showAddToPlaylist(context, t)),
              ]),
              StreamBuilder<Duration?>(
                stream: p.durationStream,
                builder: (_, dSnap) {
                  final dur = dSnap.data ?? Duration.zero;
                  return StreamBuilder<Duration>(
                    stream: p.positionStream,
                    builder: (_, pSnap) {
                      final pos = pSnap.data ?? Duration.zero;
                      final max = dur.inMilliseconds.toDouble();
                      return Column(children: [
                        Slider(
                          value: max <= 0 ? 0 : pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble(),
                          max: max <= 0 ? 1 : max,
                          onChanged: max <= 0 ? null : (v) => p.seek(Duration(milliseconds: v.round())),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(_fmt(pos), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            Text(_fmt(dur), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ]),
                        ),
                      ]);
                    },
                  );
                },
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                IconButton(
                  icon: Icon(Icons.shuffle, color: p.shuffleModeEnabled ? cyan : Colors.white38),
                  onPressed: music.toggleShuffle,
                ),
                IconButton(iconSize: 40, icon: const Icon(Icons.skip_previous_rounded), onPressed: p.seekToPrevious),
                StreamBuilder<PlayerState>(
                  stream: p.playerStateStream,
                  builder: (_, snap) {
                    final st = snap.data;
                    final loading = st?.processingState == ProcessingState.loading || st?.processingState == ProcessingState.buffering;
                    final playing = st?.playing ?? false;
                    return loading
                        ? const SizedBox(width: 64, height: 64, child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                        : IconButton(
                            iconSize: 64, color: violet,
                            icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill),
                            onPressed: () => playing ? p.pause() : p.play(),
                          );
                  },
                ),
                IconButton(iconSize: 40, icon: const Icon(Icons.skip_next_rounded), onPressed: p.seekToNext),
                IconButton(
                  icon: Icon(p.loopMode == LoopMode.one ? Icons.repeat_one : Icons.repeat,
                      color: p.loopMode == LoopMode.off ? Colors.white38 : cyan),
                  onPressed: music.cycleLoop,
                ),
              ]),
            ]),
          );
        },
      );
}

// ===================================================== Equalizer + sleep timer
class SoundScreen extends StatelessWidget {
  const SoundScreen({super.key});

  String _freq(double hz) => hz >= 1000 ? '${(hz / 1000).toStringAsFixed(hz % 1000 == 0 ? 0 : 1)} kHz' : '${hz.round()} Hz';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: music,
        builder: (context, _) {
          final params = music.eqParams;
          return Scaffold(
            appBar: AppBar(backgroundColor: bg, title: const Text('Equalizer & sleep timer')),
            body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
              const Text('EQUALIZER', style: TextStyle(color: cyan, letterSpacing: 2, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (params == null)
                const Text('Equalizer is not available on this device, or starts after you play a track.',
                    style: TextStyle(color: Colors.white54))
              else ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable equalizer'),
                  value: music.eqEnabled,
                  onChanged: music.setEqEnabled,
                ),
                Wrap(spacing: 8, children: [
                  for (final n in ['Flat', 'Bass', 'Vocal', 'Treble'])
                    ChoiceChip(
                      label: Text(n),
                      selected: music.eqPreset == n,
                      selectedColor: violet,
                      backgroundColor: panel,
                      labelStyle: TextStyle(color: music.eqPreset == n ? Colors.black : Colors.white70),
                      onSelected: (_) {
                        music.setEqEnabled(true);
                        music.applyPreset(n);
                      },
                    ),
                ]),
                const SizedBox(height: 8),
                for (var i = 0; i < params.bands.length; i++)
                  Row(children: [
                    SizedBox(width: 64, child: Text(_freq(params.bands[i].centerFrequency), style: const TextStyle(color: Colors.white60, fontSize: 12))),
                    Expanded(
                      child: Slider(
                        min: params.minDecibels,
                        max: params.maxDecibels,
                        value: music.eqGains[i].clamp(params.minDecibels, params.maxDecibels).toDouble(),
                        onChanged: (v) => music.setBandGain(i, v),
                      ),
                    ),
                    SizedBox(width: 44, child: Text('${music.eqGains[i].toStringAsFixed(1)} dB', style: const TextStyle(color: Colors.white38, fontSize: 10))),
                  ]),
              ],
              const SizedBox(height: 28),
              const Text('SLEEP TIMER', style: TextStyle(color: cyan, letterSpacing: 2, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (music.sleepEnd != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Music stops at ${TimeOfDay.fromDateTime(music.sleepEnd!).format(context)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final m in [15, 30, 45, 60, 90])
                  ActionChip(
                    label: Text('$m min'),
                    backgroundColor: panel,
                    onPressed: () {
                      music.setSleepTimer(Duration(minutes: m));
                      _snack(context, 'Sleep timer set for $m minutes');
                    },
                  ),
                ActionChip(
                  label: const Text('Off'),
                  backgroundColor: panel,
                  onPressed: () => music.setSleepTimer(null),
                ),
              ]),
            ]),
            bottomNavigationBar: const MiniPlayer(),
          );
        },
      );
}


// ===================================================== Country & language picker
void showRegionPicker(BuildContext context) {
  String q = '';
  showModalBottomSheet(
    context: context,
    backgroundColor: panel,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * .7,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(children: [
                const Expanded(
                  child: Text('Your countries & languages',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('DONE')),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search country or language',
                  filled: true, fillColor: bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                onChanged: (v) => setSheet(() => q = v.toLowerCase()),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: music,
                builder: (_, __) => ListView(children: [
                  ListTile(
                    leading: const Text('\ud83c\udf0d', style: TextStyle(fontSize: 22)),
                    title: const Text('Global (clear all)'),
                    onTap: () {
                      for (final r in List.of(music.selectedRegions)) {
                        music.toggleRegion(r);
                      }
                    },
                  ),
                  for (final r in regions.where((r) =>
                      q.isEmpty ||
                      r.country.toLowerCase().contains(q) ||
                      r.language.toLowerCase().contains(q)))
                    ListTile(
                      leading: Text(r.flag, style: const TextStyle(fontSize: 22)),
                      title: Text(r.country),
                      subtitle: Text(r.language),
                      trailing: music.isRegionSelected(r)
                          ? const Icon(Icons.check_circle, color: cyan)
                          : const Icon(Icons.circle_outlined, color: Colors.white24),
                      onTap: () => music.toggleRegion(r),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    ),
  );
}
