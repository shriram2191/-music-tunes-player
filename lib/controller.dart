import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_review/in_app_review.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'regions.dart';

class Track {
  Track({required this.title, required this.path, this.artist = 'Local audio', this.isOnline = false, this.image = ''});
  final String title;
  final String path;
  final String artist;
  final bool isOnline;
  final String image;

  Map<String, dynamic> toJson() => {'title': title, 'path': path, 'artist': artist, 'online': isOnline, 'image': image};
  factory Track.fromJson(Map<String, dynamic> j) => Track(
        title: (j['title'] ?? 'Untitled').toString(),
        path: (j['path'] ?? '').toString(),
        artist: (j['artist'] ?? '').toString(),
        isOnline: j['online'] == true,
        image: (j['image'] ?? '').toString(),
      );
}

class Playlist {
  Playlist(this.name, [List<Track>? tracks]) : tracks = tracks ?? [];
  String name;
  final List<Track> tracks;
  Map<String, dynamic> toJson() => {'name': name, 'tracks': tracks.map((t) => t.toJson()).toList()};
  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        (j['name'] ?? 'Playlist').toString(),
        ((j['tracks'] as List?) ?? []).whereType<Map<String, dynamic>>().map(Track.fromJson).toList(),
      );
}

/// Online catalogue: Audius (primary, free, no API key) with Internet
/// Archive open audio as automatic fallback.
class Catalog {
  static const String _appName = 'MusicTunes';
  static const String _defaultHost = 'https://discoveryprovider.audius.co';
  static String? _host;

  static Future<String> _baseUrl() async {
    if (_host != null) return _host!;
    try {
      final r = await http.get(Uri.parse('https://api.audius.co')).timeout(const Duration(seconds: 6));
      final hosts = jsonDecode(r.body);
      if (hosts is List && hosts.isNotEmpty) {
        _host = hosts.first.toString();
        return _host!;
      }
    } catch (_) {}
    _host = _defaultHost;
    return _host!;
  }

  static Future<List<Track>> search(String query) async {
    try {
      return await _audius(query);
    } catch (e) {
      debugPrint('Audius failed, using Internet Archive: $e');
      _host = null;
      return _archive(query);
    }
  }

  static Future<List<Track>> _audius(String query) async {
    final base = await _baseUrl();
    final q = query.trim();
    final isPopular = q.isEmpty || q.toLowerCase() == 'popular';
    final uri = isPopular
        ? Uri.parse('$base/v1/tracks/trending?app_name=$_appName&limit=30')
        : Uri.parse('$base/v1/tracks/search?app_name=$_appName&limit=30&query=${Uri.encodeComponent(q)}');
    final List<Track> out;
    try {
      final r = await http
          .get(uri, headers: {'User-Agent': 'MusicTunes/1.1', 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) throw Exception('Audius returned HTTP ${r.statusCode}');
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final results = (data['data'] as List? ?? []).whereType<Map<String, dynamic>>();
      out = <Track>[];
      for (final t in results) {
        final id = (t['id'] ?? '').toString();
        if (id.isEmpty) continue;
        final user = t['user'] is Map<String, dynamic> ? t['user'] as Map<String, dynamic> : const <String, dynamic>{};
        final art = t['artwork'] is Map<String, dynamic> ? t['artwork'] as Map<String, dynamic> : const <String, dynamic>{};
        out.add(Track(
          title: (t['title'] ?? 'Untitled').toString(),
          artist: (user['name'] ?? 'Audius artist').toString(),
          path: '$base/v1/tracks/$id/stream?app_name=$_appName',
          isOnline: true,
          image: (art['480x480'] ?? art['150x150'] ?? '').toString(),
        ));
      }
    } on Exception {
      _host = null;
      rethrow;
    }
    if (out.isEmpty && !isPopular) _host = null;
    return out;
  }

  static Future<List<Track>> _archive(String query) async {
    final clean = query.trim();
    var sq = 'collection:opensource_audio AND mediatype:audio';
    if (clean.isNotEmpty && clean.toLowerCase() != 'popular') {
      final safe = clean.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), ' ').trim();
      if (safe.isNotEmpty) sq += ' AND title:(${safe.split(RegExp(r'\s+')).join(' AND ')})';
    }
    final uri = Uri.https('archive.org', '/advancedsearch.php', {
      'q': sq,
      'fl[]': 'identifier,title,creator',
      'rows': '18',
      'page': '1',
      'output': 'json',
      'sort[]': 'downloads desc',
    });
    final r = await http.get(uri, headers: {'User-Agent': 'MusicTunes/1.1'}).timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) throw Exception('Open audio catalogue returned HTTP ${r.statusCode}');
    final decoded = jsonDecode(r.body) as Map<String, dynamic>;
    final docs = (((decoded['response'] as Map<String, dynamic>?)?['docs']) as List?) ?? [];
    final results = await Future.wait(docs.whereType<Map<String, dynamic>>().take(12).map(_archiveItem));
    return results.whereType<Track>().toList();
  }

  static Future<Track?> _archiveItem(Map<String, dynamic> item) async {
    final id = (item['identifier'] ?? '').toString();
    if (id.isEmpty) return null;
    try {
      final mr = await http
          .get(Uri.https('archive.org', '/metadata/$id'), headers: {'User-Agent': 'MusicTunes/1.1'})
          .timeout(const Duration(seconds: 12));
      if (mr.statusCode != 200) return null;
      final meta = jsonDecode(mr.body) as Map<String, dynamic>;
      final files = (meta['files'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
      final audio = files.where((f) {
        final name = (f['name'] ?? '').toString().toLowerCase();
        final format = (f['format'] ?? '').toString().toLowerCase();
        return !name.startsWith('__ia_thumb') &&
            (name.endsWith('.mp3') || name.endsWith('.ogg') || name.endsWith('.m4a') ||
                format.contains('mpeg layer iii') || format == 'ogg vorbis');
      }).toList();
      if (audio.isEmpty) return null;
      audio.sort((a, b) {
        int rank(Map f) => (f['name'] ?? '').toString().toLowerCase().endsWith('.mp3') ? 0 : 1;
        return rank(a).compareTo(rank(b));
      });
      final fileName = (audio.first['name'] ?? '').toString();
      if (fileName.isEmpty) return null;
      final enc = fileName.split('/').map(Uri.encodeComponent).join('/');
      final url = 'https://archive.org/download/${Uri.encodeComponent(id)}/$enc';
      final md = (meta['metadata'] as Map<String, dynamic>?) ?? {};
      final creator = md['creator'] ?? item['creator'] ?? 'Independent artist';
      final title = md['title'] ?? item['title'] ?? 'Open audio';
      return Track(
        title: title is List ? title.join(', ') : title.toString(),
        artist: creator is List ? creator.join(', ') : creator.toString(),
        path: url,
        isOnline: true,
        image: 'https://archive.org/services/img/${Uri.encodeComponent(id)}',
      );
    } catch (_) {
      return null;
    }
  }
}

class MusicController extends ChangeNotifier {
  final AndroidEqualizer eq = AndroidEqualizer();
  late final AudioPlayer player = AudioPlayer(audioPipeline: AudioPipeline(androidAudioEffects: [eq]));

  final List<Track> library = [];
  final List<Track> favourites = [];
  final List<Track> recent = [];
  final List<Playlist> playlists = [];

  List<Track> queue = [];
  Track? current;
  String? lastError;

  // Online
  final List<Track> onlineTracks = [];
  bool onlineLoading = false;
  String? onlineError;
  String onlineCategory = 'Featured';
  String _lastQuery = 'popular';
  int _searchSeq = 0;

  // Regions (multi-select country/language markets)
  final List<Region> selectedRegions = [];
  final Map<String, List<Track>> regionalCharts = {};

  // Downloads (online url -> local file path)
  final Map<String, String> downloads = {};

  // Equalizer
  AndroidEqualizerParameters? eqParams;
  List<double> eqGains = [];
  String eqPreset = 'Flat';
  bool eqEnabled = false;

  // Sleep timer
  Timer? _sleepTimer;
  DateTime? sleepEnd;

  // Weekly recap
  final _notifs = FlutterLocalNotificationsPlugin();
  int weekPlays = 0;

  final _errors = StreamController<String>.broadcast();
  Stream<String> get errors => _errors.stream;

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    List<Track> readTracks(String key) {
      try {
        final raw = _prefs!.getString(key);
        if (raw == null) return [];
        return (jsonDecode(raw) as List).whereType<Map<String, dynamic>>().map(Track.fromJson).toList();
      } catch (_) {
        return [];
      }
    }

    library.addAll(readTracks('library'));
    favourites.addAll(readTracks('favourites_v2'));
    recent.addAll(readTracks('recent'));
    try {
      final raw = _prefs!.getString('playlists');
      if (raw != null) {
        playlists.addAll((jsonDecode(raw) as List).whereType<Map<String, dynamic>>().map(Playlist.fromJson));
      }
    } catch (_) {}
    try {
      final raw = _prefs!.getString('downloads');
      if (raw != null) {
        (jsonDecode(raw) as Map<String, dynamic>).forEach((k, v) {
          final f = File(v.toString());
          if (f.existsSync()) downloads[k] = f.path;
        });
      }
    } catch (_) {}
    eqPreset = _prefs!.getString('eq_preset') ?? 'Flat';
    _restoreOnlineCache();
    _restoreRegion();

    // sequenceState is shuffle-aware; currentIndexStream is not.
    player.sequenceStateStream.listen(_onSequenceState);
    player.playerStateStream.listen((_) => notifyListeners());
    player.playbackEventStream.listen((_) {}, onError: (Object e, StackTrace s) {
      debugPrint('Playback error: $e\n$s');
      reportError('Playback error. Check your connection or try another track.');
    });

    notifyListeners();
    unawaited(_initEq());
    unawaited(_requestNotificationPermission());
    unawaited(_initNotifications());
    unawaited(_scheduleRecap());
    loadOnline('Featured');
  }

  void _onSequenceState(SequenceState? state) {
    final tag = state?.currentSource?.tag;
    if (tag is MediaItem) {
      final i = queue.indexWhere((t) => t.path == tag.id);
      if (i >= 0 && !identical(current, queue[i])) {
        current = queue[i];
        _pushRecent(queue[i]);
        _countPlay();
        notifyListeners();
      }
    }
  }

  // ---------- Errors ----------
  void reportError(String message) {
    lastError = message;
    _errors.add(message);
    notifyListeners();
  }

  void _savePrefs() {
    final p = _prefs;
    if (p == null) return;
    p.setString('library', jsonEncode(library.map((t) => t.toJson()).toList()));
    p.setString('favourites_v2', jsonEncode(favourites.map((t) => t.toJson()).toList()));
    p.setString('recent', jsonEncode(recent.map((t) => t.toJson()).toList()));
    p.setString('playlists', jsonEncode(playlists.map((t) => t.toJson()).toList()));
  }

  void _pushRecent(Track t) {
    recent.removeWhere((x) => x.path == t.path);
    recent.insert(0, t);
    if (recent.length > 20) recent.removeRange(20, recent.length);
    _savePrefs();
  }

  /// Auto-built mix for the Home "Made for you today" row.
  List<Track> get dailyMix {
    final seen = <String>{};
    final pool = [...favourites, ...recent, ...library, ...onlineTracks];
    final mix = pool.where((t) => seen.add(t.path)).toList();
    final seed = DateTime.now().day + DateTime.now().month * 31;
    mix.shuffle(Random(seed));
    return mix.take(15).toList();
  }

  // ---------- Library ----------
  void addToLibrary(Iterable<Track> tracks) {
    for (final t in tracks) {
      if (!library.any((x) => x.path == t.path)) library.add(t);
    }
    _savePrefs();
    notifyListeners();
  }

  void removeFromLibrary(Track t) {
    library.removeWhere((x) => x.path == t.path);
    _savePrefs();
    notifyListeners();
  }

  // ---------- Favourites ----------
  bool isFav(Track t) => favourites.any((x) => x.path == t.path);

  void toggleFav(Track t) {
    if (isFav(t)) {
      favourites.removeWhere((x) => x.path == t.path);
    } else {
      favourites.insert(0, t);
      _maybeAskReview(); // happy moment: 3rd favourite
    }
    _savePrefs();
    notifyListeners();
  }

  Future<void> _maybeAskReview() async {
    if (favourites.length != 3) return;
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) await review.requestReview();
    } catch (_) {}
  }

  // ---------- Playlists ----------
  Playlist createPlaylist(String name) {
    final p = Playlist(name.trim().isEmpty ? 'My playlist' : name.trim());
    playlists.add(p);
    _savePrefs();
    notifyListeners();
    return p;
  }

  void addToPlaylist(Playlist p, Track t) {
    if (!p.tracks.any((x) => x.path == t.path)) p.tracks.add(t);
    _savePrefs();
    notifyListeners();
  }

  void removeFromPlaylist(Playlist p, Track t) {
    p.tracks.removeWhere((x) => x.path == t.path);
    _savePrefs();
    notifyListeners();
  }

  void deletePlaylist(Playlist p) {
    playlists.remove(p);
    _savePrefs();
    notifyListeners();
  }

  // ---------- Downloads ----------
  bool isDownloaded(Track t) {
    final p = downloads[t.path];
    return p != null && File(p).existsSync();
  }

  Future<String?> downloadTrack(Track t) async {
    if (!t.isOnline) return 'Only online tracks can be downloaded.';
    if (isDownloaded(t)) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/downloads/${t.path.hashCode.toRadixString(16)}.mtune');
      await file.parent.create(recursive: true);
      final r = await http.get(Uri.parse(t.path)).timeout(const Duration(minutes: 3));
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      await file.writeAsBytes(r.bodyBytes, flush: true);
      downloads[t.path] = file.path;
      await _prefs?.setString('downloads', jsonEncode(downloads));
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Download failed: $e');
      return 'Download failed. Check your connection.';
    }
  }

  Future<void> removeDownload(Track t) async {
    final p = downloads.remove(t.path);
    if (p != null) {
      try {
        await File(p).delete();
      } catch (_) {}
    }
    await _prefs?.setString('downloads', jsonEncode(downloads));
    notifyListeners();
  }

  // ---------- Playback ----------
  AudioSource _source(Track t) {
    final cached = t.isOnline ? downloads[t.path] : null;
    final uri = (cached != null && File(cached).existsSync())
        ? Uri.file(cached)
        : (t.isOnline ? Uri.parse(t.path) : Uri.file(t.path));
    final item = MediaItem(
      id: t.path,
      title: t.title,
      artist: t.artist,
      artUri: t.image.isNotEmpty ? Uri.tryParse(t.image) : null,
    );
    return AudioSource.uri(uri, tag: item);
  }

  Future<String?> playQueue(List<Track> tracks, int index) async {
    if (tracks.isEmpty) return null;
    final i = index.clamp(0, tracks.length - 1);
    try {
      final source = ConcatenatingAudioSource(children: tracks.map(_source).toList());
      await player.setAudioSource(source, initialIndex: i, initialPosition: Duration.zero);
      queue = List.of(tracks);
      current = queue[i];
      notifyListeners();
      await player.play();
      return null;
    } catch (e) {
      debugPrint('playQueue failed: $e');
      reportError('Could not play this track.');
      return 'Could not play this track. It may be unavailable or in an unsupported format.';
    }
  }

  Future<void> toggleShuffle() async {
    final on = !player.shuffleModeEnabled;
    if (on) await player.shuffle();
    await player.setShuffleModeEnabled(on);
    notifyListeners();
  }

  Future<void> cycleLoop() async {
    final next = {
      LoopMode.off: LoopMode.all,
      LoopMode.all: LoopMode.one,
      LoopMode.one: LoopMode.off,
    }[player.loopMode]!;
    await player.setLoopMode(next);
    notifyListeners();
  }

  // ---------- Online ----------
  static const categoryTerms = <String, String>{
    'Featured': 'popular', 'Pop': 'pop', 'Chill': 'chill', 'Electronic': 'electronic',
    'Rock': 'rock', 'Hip-Hop': 'hip hop', 'Acoustic': 'acoustic', 'Jazz': 'jazz',
  };

  Future<void> loadOnline(String category) async {
    onlineCategory = category;
    await searchOnline(categoryTerms[category] ?? category);
  }

  Future<void> retryOnline() => searchOnline(_lastQuery);

  Future<void> searchOnline(String query) async {
    final seq = ++_searchSeq;
    _lastQuery = query;
    onlineLoading = true;
    onlineError = null;
    notifyListeners();
    try {
      final found = await Catalog.search(query);
      if (seq != _searchSeq) return;
      onlineTracks
        ..clear()
        ..addAll(found);
      if (found.isEmpty) {
        onlineError = 'No playable tracks found. Try another search.';
      } else {
        _prefs?.setString('online_cache_query', query);
        _prefs?.setString('online_cache', jsonEncode(found.map((t) => t.toJson()).toList()));
      }
    } catch (e) {
      if (seq != _searchSeq) return;
      debugPrint('Catalog error: $e');
      onlineError = 'Could not load online music. Check your connection.';
    } finally {
      if (seq == _searchSeq) {
        onlineLoading = false;
        notifyListeners();
      }
    }
  }

  void _restoreOnlineCache() {
    try {
      final raw = _prefs!.getString('online_cache');
      if (raw == null) return;
      onlineTracks.addAll((jsonDecode(raw) as List).whereType<Map<String, dynamic>>().map(Track.fromJson));
      final q = _prefs!.getString('online_cache_query');
      if (q != null) {
        _lastQuery = q;
        final match = categoryTerms.entries.where((e) => e.value == q);
        onlineCategory = match.isEmpty ? '' : match.first.key;
      }
    } catch (_) {}
  }

  // ---------- Regions ----------
  String get regionFlag => selectedRegions.isEmpty ? '\ud83c\udf10' : selectedRegions.first.flag;

  void _restoreRegion() {
    selectedRegions.clear();
    try {
      final saved = _prefs!.getString('region_country');
      if (saved != null && saved.isNotEmpty) {
        final names = (jsonDecode(saved) as List).map((e) => e.toString()).toList();
        selectedRegions.addAll(regions.where((r) => names.contains(r.country)));
      }
      if (selectedRegions.isEmpty) {
        final cc = Platform.localeName.split('_').last.toUpperCase();
        for (final r in regions) {
          if (r.countryCode == cc) {
            selectedRegions.add(r);
            break;
          }
        }
      }
    } catch (_) {}
    if (selectedRegions.isNotEmpty) loadRegionalCharts();
  }

  bool isRegionSelected(Region r) => selectedRegions.any((x) => x.country == r.country);

  Future<void> toggleRegion(Region r) async {
    if (isRegionSelected(r)) {
      selectedRegions.removeWhere((x) => x.country == r.country);
      regionalCharts.remove(r.country);
    } else {
      selectedRegions.add(r);
    }
    await _prefs?.setString('region_country', jsonEncode(selectedRegions.map((r) => r.country).toList()));
    notifyListeners();
    loadRegionalCharts();
  }

  Future<void> loadRegionalCharts() async {
    await Future.wait(selectedRegions.map((r) async {
      try {
        final results = await Future.wait(r.terms.take(2).map(Catalog.search));
        final seen = <String>{};
        regionalCharts[r.country] =
            results.expand((x) => x).where((t) => seen.add(t.path)).take(20).toList();
      } catch (e) {
        debugPrint('Chart failed for ${r.country}: $e');
      }
    }));
    notifyListeners();
  }

  // ---------- Equalizer ----------
  Future<void> _initEq() async {
    try {
      final params = await eq.parameters;
      eqParams = params;
      eqGains = params.bands.map((b) => b.gain).toList();
      eqEnabled = _prefs?.getBool('eq_enabled') ?? false;
      await eq.setEnabled(eqEnabled);
      eqPreset = _prefs?.getString('eq_preset') ?? 'Flat';
      if (eqPreset == 'Custom') {
        _restoreEqGains(params);
      } else {
        _applyPresetGains(eqPreset);
      }
    } catch (_) {
      eqParams = null;
    }
    notifyListeners();
  }

  void _restoreEqGains(AndroidEqualizerParameters p) {
    try {
      final stored = (jsonDecode(_prefs?.getString('eq_gains') ?? '[]') as List)
          .map((e) => (e as num).toDouble()).toList();
      for (var i = 0; i < p.bands.length && i < stored.length; i++) {
        final v = stored[i].clamp(p.minDecibels, p.maxDecibels).toDouble();
        eqGains[i] = v;
        p.bands[i].setGain(v);
      }
    } catch (_) {}
  }

  void applyPreset(String name) {
    eqPreset = name;
    _applyPresetGains(name);
    _prefs?.setString('eq_preset', name);
    _saveEqGains();
    notifyListeners();
  }

  void _applyPresetGains(String name) {
    final p = eqParams;
    if (p == null) return;
    final n = p.bands.length;
    for (var i = 0; i < n; i++) {
      final t = n == 1 ? 0.0 : i / (n - 1);
      double frac;
      switch (name) {
        case 'Bass':
          frac = 0.7 * (1 - 2 * t).clamp(0.0, 1.0).toDouble();
          break;
        case 'Vocal':
          frac = 0.5 * (1 - (2 * t - 1).abs());
          break;
        case 'Treble':
          frac = 0.7 * (2 * t - 1).clamp(0.0, 1.0).toDouble();
          break;
        default:
          frac = 0;
      }
      final v = (p.maxDecibels * frac).clamp(p.minDecibels, p.maxDecibels).toDouble();
      eqGains[i] = v;
      p.bands[i].setGain(v);
    }
  }

  void setBandGain(int i, double db) {
    final p = eqParams;
    if (p == null || i < 0 || i >= p.bands.length) return;
    final v = db.clamp(p.minDecibels, p.maxDecibels).toDouble();
    eqGains[i] = v;
    p.bands[i].setGain(v);
    eqPreset = 'Custom';
    _prefs?.setString('eq_preset', 'Custom');
    _saveEqGains();
    notifyListeners();
  }

  void _saveEqGains() => _prefs?.setString('eq_gains', jsonEncode(eqGains));

  Future<void> setEqEnabled(bool on) async {
    eqEnabled = on;
    await eq.setEnabled(on);
    _prefs?.setBool('eq_enabled', on);
    notifyListeners();
  }

  // ---------- Sleep timer ----------
  void setSleepTimer(Duration? d) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepEnd = null;
    if (d != null) {
      sleepEnd = DateTime.now().add(d);
      _sleepTimer = Timer(d, () async {
        await player.pause();
        sleepEnd = null;
        _sleepTimer = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  // ---------- Notifications ----------
  Future<void> _requestNotificationPermission() async {
    if (kIsWeb) return;
    try {
      if (Platform.isAndroid) await Permission.notification.request();
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  Future<void> _initNotifications() async {
    try {
      await _notifs.initialize(
        const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      );
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  static DateTime _weekStart(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

  void _countPlay() {
    final ws = _weekStart(DateTime.now()).toIso8601String();
    if (_prefs?.getString('week_start') != ws) {
      _prefs?.setString('week_start', ws);
      weekPlays = 0;
    }
    weekPlays++;
    _prefs?.setInt('week_plays', weekPlays);
  }

  /// Next Monday 09:00 local, inexact alarm (no special permission needed).
  Future<void> _scheduleRecap() async {
    try {
      tzdata.initializeTimeZones();
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.name));
      final now = tz.TZDateTime.now(tz.local);
      var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9);
      var days = (8 - now.weekday) % 7;
      if (days == 0 && !now.isBefore(next)) days = 7;
      next = next.add(Duration(days: days));
      await _notifs.zonedSchedule(
        1001,
        'Your week in music \ud83c\udfa7',
        'You played $weekPlays tracks this week. Tap for your mix.',
        next,
        const NotificationDetails(android: AndroidNotificationDetails('recap', 'Weekly recap')),
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Recap schedule failed: $e');
    }
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _errors.close();
    player.dispose();
    super.dispose();
  }
}
