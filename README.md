# Music Tunes — Play Store preparation starter

This is a Flutter starter branded **Music Tunes**, using the selected bright logo artwork and an AMOLED-style UI. It intentionally contains no advertising SDK dependencies.

## Important: not release-ready yet
The project is not a complete music service and no APK/AAB has been built. Online music catalogue integration, reliable background playback/notification controls, persistent playlists/queue, and real equalizer processing still need implementation and tests. A legitimate provider and the right streaming permissions are required for online music.

## Files
- `lib/main.dart` — starter UI and playback code
- `assets/brand/music_tunes_logo.png` — selected bright logo design source
- `android/app/src/main/AndroidManifest.xml` — starter manifest; generated Android scaffolding is still required
- `PLAY_STORE_CHECKLIST.md` — release checklist and draft store description

## Build environment
Install Flutter stable, Android Studio, and Android SDK. From the project directory run:

```sh
flutter create .
flutter pub get
flutter analyze
flutter test
flutter run
```

Review the generated Android files, set a unique application ID in Gradle, create proper launcher/adaptive icons from the supplied logo, and test on devices. Once the unfinished features are implemented and tests pass:

```sh
flutter build appbundle --release
```

Expected output: `build/app/outputs/bundle/release/app-release.aab`. This output will not be produced until you run the build in an installed Flutter/Android environment.

Read `PLAY_STORE_CHECKLIST.md` before submitting.
