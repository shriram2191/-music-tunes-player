import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MusicTunesApp());

const bg = Color(0xFF050609);
const panel = Color(0xFF11131A);
const violet = Color(0xFF9B7BFF);
const cyan = Color(0xFF55E6D0);

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
      fontFamily: 'Roboto',
    ),
    home: const MusicHome(),
  );
}

class Track {
  Track({required this.title, required this.path, this.artist = 'Local audio'});
  final String title;
  final String path;
  final String artist;
}

class MusicHome extends StatefulWidget {
  const MusicHome({super.key});
  @override
  State<MusicHome> createState() => _MusicHomeState();
}

class _MusicHomeState extends State<MusicHome> {
  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _search = TextEditingController();
  final List<Track> _tracks = [];
  final Set<String> _favourites = {};
  int _tab = 0;
  int? _current;
  bool _shuffle = false;
  double _volume = 0.8;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadFavourites();
  }

  Future<void> _loadFavourites() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _favourites.addAll(prefs.getStringList('favourites') ?? []));
  }

  Future<void> _saveFavourites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favourites', _favourites.toList());
  }

  Future<void> _addFiles() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: true);
    if (result == null) return;
    final additions = result.files.where((f) => f.path != null).map((f) =>
      Track(title: f.name.replaceAll(RegExp(r'\.[^.]+$'), ''), path: f.path!));
    setState(() {
      for (final t in additions) {
        if (!_tracks.any((x) => x.path == t.path)) _tracks.add(t);
      }
    });
  }

  Future<void> _play(int index) async {
    final track = _tracks[index];
    try {
      await _player.setFilePath(track.path);
      await _player.play();
      if (mounted) setState(() => _current = index);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not play this file: $e')));
    }
  }

  List<Track> get _visibleTracks {
    final source = _tab == 2 ? _tracks.where((t) => _favourites.contains(t.path)).toList() : _tracks;
    if (_query.trim().isEmpty) return source;
    return source.where((t) => t.title.toLowerCase().contains(_query.toLowerCase()) ||
      t.artist.toLowerCase().contains(_query.toLowerCase())).toList();
  }

  @override
  void dispose() {
    _search.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Discover', 'Your Library', 'Favourites', 'Equalizer'];
    return Scaffold(
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
          child: Row(children: [
            Container(width: 42, height: 42,
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [violet, cyan]),
                borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.graphic_eq_rounded, color: Colors.black, size: 26)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('MUSIC TUNES', style: TextStyle(letterSpacing: 2.6, fontWeight: FontWeight.w900, fontSize: 18)),
              Text('YOUR SOUND. YOUR SPACE.', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1.5)),
            ])),
            IconButton(onPressed: _addFiles, icon: const Icon(Icons.add_circle_outline, color: cyan, size: 28),
              tooltip: 'Add music files'),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search your music',
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
              filled: true, fillColor: panel,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Container(
            width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF27203E), Color(0xFF111820), Color(0xFF101116)]),
              border: Border.all(color: Colors.white.withOpacity(.07)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SOUND WITHOUT LIMITS', style: TextStyle(color: cyan, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('Your music,\\nyour mood.', style: TextStyle(fontSize: 29, height: 1.1, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Row(children: [
                FilledButton.icon(onPressed: _addFiles, icon: const Icon(Icons.library_music_rounded),
                  label: const Text('Add music'), style: FilledButton.styleFrom(backgroundColor: violet, foregroundColor: Colors.black)),
                const SizedBox(width: 10),
                Text('${_tracks.length} tracks', style: const TextStyle(color: Colors.white60)),
              ]),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
          child: Row(children: [
            Expanded(child: Text(titles[_tab], style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold))),
            if (_tab == 1 || _tab == 0) TextButton(onPressed: _addFiles, child: const Text('ADD FILES')),
          ]),
        ),
        Expanded(child: _tab == 3 ? _equalizerView() : _trackList()),
        _miniPlayer(),
        NavigationBar(
          backgroundColor: const Color(0xFF0B0C10),
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music), label: 'Library'),
            NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Liked'),
            NavigationDestination(icon: Icon(Icons.equalizer), selectedIcon: Icon(Icons.equalizer), label: 'EQ'),
          ],
        ),
      ])),
    );
  }

  Widget _trackList() {
    final tracks = _visibleTracks;
    if (tracks.isEmpty) return Center(child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(_tab == 2 ? Icons.favorite_border : Icons.headphones_rounded, size: 44, color: violet),
        const SizedBox(height: 12),
        Text(_tab == 2 ? 'Your favourites will live here' : 'Your library is ready for your music',
          style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text('Tap + to choose audio files stored on your phone.',
          style: TextStyle(color: Colors.white38), textAlign: TextAlign.center),
      ]),
    ));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
      itemCount: tracks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final t = tracks[i];
        final isPlaying = _current != null && _tracks[_current!].path == t.path && _player.playing;
        return Container(
          decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            onTap: () => _play(_tracks.indexWhere((x) => x.path == t.path)),
            leading: Container(width: 46, height: 46,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(colors: [Color(0xFF30234D), Color(0xFF163238)])),
              child: Icon(isPlaying ? Icons.graphic_eq : Icons.music_note_rounded, color: cyan)),
            title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(t.artist, style: const TextStyle(color: Colors.white38, fontSize: 12)),
            trailing: IconButton(
              icon: Icon(_favourites.contains(t.path) ? Icons.favorite : Icons.favorite_border,
                color: _favourites.contains(t.path) ? violet : Colors.white38),
              onPressed: () async {
                setState(() => _favourites.contains(t.path) ? _favourites.remove(t.path) : _favourites.add(t.path));
                await _saveFavourites();
              }),
          ),
        );
      },
    );
  }

  Widget _equalizerView() => ListView(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    children: [
      const SizedBox(height: 12),
      const Text('SOUND PROFILE', style: TextStyle(color: cyan, letterSpacing: 2, fontSize: 11, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: ['Flat', 'Bass', 'Vocal', 'Treble'].map((s) =>
        OutlinedButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('EQ presets need a platform equalizer integration in the next build.'))),
          child: Text(s)).copyWithStyle()).toList()),
      const SizedBox(height: 12),
      const Text('Equalizer controls are a UI placeholder in this starter. A device/platform EQ needs to be integrated and tested before release.',
        style: TextStyle(color: Colors.white54, height: 1.5)),
    ],
  );

  Widget _miniPlayer() => Container(
    margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: const Color(0xFF171922), borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withOpacity(.06))),
    child: Row(children: [
      Container(width: 42, height: 42, decoration: BoxDecoration(
        color: const Color(0xFF28213E), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.album_rounded, color: violet)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_current == null ? 'Nothing playing yet' : _tracks[_current!].title,
          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        const Text('MUSIC TUNES PLAYER', style: TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1.2)),
      ])),
      IconButton(onPressed: () => setState(() => _shuffle = !_shuffle),
        icon: Icon(Icons.shuffle, color: _shuffle ? cyan : Colors.white38, size: 20)),
      StreamBuilder<PlayerState>(
        stream: _player.playerStateStream,
        builder: (context, snapshot) {
          final playing = snapshot.data?.playing ?? false;
          return IconButton(onPressed: () => playing ? _player.pause() : _player.play(),
            icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill, color: violet, size: 34));
        },
      ),
    ]),
  );
}

extension on OutlinedButton {
  Widget copyWithStyle() => this;
}
