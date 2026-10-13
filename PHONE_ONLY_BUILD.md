# Build Music Tunes APK using only your phone

This project cannot be compiled in the ChatGPT execution environment because Flutter, the Android SDK and Android build tools are not installed, and network access to install them is unavailable. This workflow lets GitHub's cloud runner attempt a build. It is a **debug/testing APK**, not a Play Store release.

## Phone-only steps
1. Open https://github.com in your phone browser and sign in/create an account.
2. Create a **new public repository** named `music-tunes-player` (public is easiest for this workflow).
3. Extract this ZIP on your phone if your file manager supports ZIP extraction. Upload the contents of the `music_tunes_play_store_source` folder to the repository using **Add file → Upload files**. Include the hidden `.github` folder and its `workflows/build-apk.yml` file; if GitHub's mobile upload UI hides dot-folders, use GitHub's desktop-site view or create the workflow file manually at `.github/workflows/build-apk.yml`.
4. On GitHub, open the repository's **Actions** tab and enable workflows if asked. Select **Build Music Tunes APK**, then tap **Run workflow**.
5. If the build succeeds, open that workflow run and download the artifact named `music-tunes-debug-apk`. Unzip it on your phone; the APK inside is `app-debug.apk`.
6. On Android, open the APK and allow installation from your browser/file manager if prompted. Only install builds from your own repository.

## Important limitations
- The cloud workflow may fail if Flutter/Android project generation or source analysis reveals issues; inspect the failed run's logs.
- This is only a starter app: online music catalogue integration is not implemented; the equalizer is a placeholder; background playback/notification controls and robust persistent library/playlist support are not finished.
- The APK produced by this workflow is for **testing only**. Do not upload it to Google Play. Before public release, fix all build/runtime issues, implement licensed online playback, test on devices, generate a signed release AAB and complete Play Console declarations.
- The app's application ID should be finalised before any Play Store release.
