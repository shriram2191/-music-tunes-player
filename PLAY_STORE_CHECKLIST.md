# Music Tunes — Google Play release checklist

## Current status
This package is a Flutter starter, not a release build. It has not been compiled, device-tested, signed, or submitted. Online music, robust background playback, persistent playlists/queue, and real equalizer processing still require implementation and testing.

## Before building
- [ ] Install Flutter stable and Android Studio/Android SDK.
- [ ] Extract this project and run `flutter create .` to generate the missing platform scaffolding. Review generated files rather than overwriting project code blindly.
- [ ] Choose a unique application ID (example format: `com.yourpublisher.musictunes`) and set it in the Android Gradle configuration before first Play upload. It cannot be changed for updates to the same Play listing.
- [ ] Generate Android launcher icon assets from the supplied logo. The supplied logo is a design source, not yet a full adaptive-icon set.
- [ ] Implement and test foreground/background playback, notification and lock-screen controls, audio focus, playlist persistence, and equalizer behavior.
- [ ] Choose a licensed online music provider/API and confirm commercial/public app use, playback, attribution, territories, and caching/offline terms. Do not scrape copyrighted audio or expose private API keys in the app.
- [ ] Check GPL/copyright notices and source-distribution obligations if any Bloomee/GPL code or assets are reused. This starter does not itself include the original Bloomee source.
- [ ] Write a privacy policy that accurately describes actual data collection and third-party services. Host it at a public HTTPS URL.
- [ ] Set `targetSdk` to the current Google Play requirement at release time (as of August 31, 2026, new apps/updates must target Android 16 / API 36).
- [ ] Run `flutter pub get`, `flutter analyze`, automated tests, and real-device tests. Fix every release-blocking issue.
- [ ] Build a release AAB: `flutter build appbundle --release`.
- [ ] Securely back up the upload key and signing credentials. Never share them in chat or commit them to source control.

## Play Console steps
1. Create a developer account at https://play.google.com/console/ and complete identity/contact verification. The registration fee is US$25 one time.
2. Create the app as **Music Tunes**, select app (not game), free/paid, default language, and support email.
3. Complete store listing, app access, ads declaration (no ads only if true), content rating, target audience, Data safety, privacy policy, permissions declarations, and app category.
4. Upload the AAB to internal testing and test on real devices.
5. For new personal accounts created after Nov 13, 2023, complete a closed test with at least 12 testers opted in continuously for 14 days, then apply for production access.
6. Resolve Play pre-launch report issues, submit for review, and wait for approval.

## Store listing draft
**Short description (draft):** An ad-free music player for your phone’s music library, with playlists and favourites.

**Full description (draft — update after implementation):** Music Tunes is an AMOLED-style music player designed for listening to audio stored on your device. Organise tracks, search your library, create playlists, save favourites, and control playback. Online music will be offered only through supported, authorised music providers. No ads are included. Feature availability may depend on device support and the final online provider integration.

Do not publish claims about online streaming, equalizer, or background playback until each feature is implemented and verified.
