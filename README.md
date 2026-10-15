# Music Tunes — free music streaming & player

AMOLED-style Flutter music player with free online streaming (no signup),
regional charts, offline playback, and an ad-supported free tier.

## Features
- **Stream free** — millions of tracks via Audius (Internet Archive fallback), no account needed
- **Country & language** — pin one or more markets (auto-detected on first run), regional chart rows
- **Your library** — plays local audio files too, with search
- **Offline playback** — cache online tracks and play them with no connection
- **Background playback** — notification & lock-screen controls
- **Real equalizer** — presets + per-band sliders, persisted
- **Sleep timer, playlists, favourites, recently played, queue** — all saved on device
- **Made for you today** — auto daily mix from your listening
- **Weekly recap notification** — "You played N tracks this week"
- **AdMob banner** on the Online tab (test IDs included — replace before release)

## Build
Install Flutter stable + Android SDK, then from the project directory:

```sh
flutter create .
flutter pub get
flutter analyze
flutter run
```

Or push to GitHub and use the **Build Android APK** workflow (Actions tab).
The APK from CI is a debug build for testing on your phone.

## Before Play release
- Replace AdMob **test IDs** in `AndroidManifest.xml` (App ID) and `lib/ads.dart` (banner unit)
- Set a unique `applicationId` in `android/app/build.gradle`
- Generate launcher icons from `assets/brand/music_tunes_logo.png`
- Build a signed release AAB (`flutter build appbundle --release`) and complete Play declarations

See `PLAY_STORE_CHECKLIST.md` and `ONLINE_MUSIC.md`.
