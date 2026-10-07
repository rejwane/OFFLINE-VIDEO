# MiniTok — Offline TikTok-style video feed

A local-only mini TikTok for videos stored on the phone. There are no accounts, backend, upload, streaming URLs, or network permission. Local creator profiles, favorites, assignments, hidden IDs, folder choice, playback speed, shuffle state, and last-played position are saved on-device.

## Features in this build

- **For You feed:** vertical full-screen swipe, autoplay current clip, pause the others, loop, tap to pause/play
- **Profile swipe:** horizontal swipe or profile avatar opens the assigned local creator; unassigned videos prompt you to choose/create one
- **Creator profiles:** multiple local profiles, gallery picture, name, description, selected videos, and a **3-column video grid**
- **For You behavior:** profile-assigned videos remain in For You as well as the creator profile
- **Likes:** persistent local favorites; double-tap likes and shows a heart animation
- **Feed tools:** gallery-folder filter, shuffle, local filename search, and a Favorites collection
- **Playback:** seekable progress bar, mute, speed menu from 0.5x through 2x
- **Share:** opens the system share sheet with the local video file
- **Delete safety:** the requested delete action is **Hide from this app**; it does not delete the source gallery file. Hidden items can be restored, and the hide action has Undo.
- **Resume:** remembers the last video and playback position; it scans pages until it finds the saved video
- **Permissions:** full/limited gallery access handling for Android and iOS
- **Offline guarantee:** cloud-only/iCloud assets are skipped and never downloaded; unavailable items show a local-only message

## Requirements

This source targets Flutter **3.44+ / Dart 3.12+**. `video_player` and `image_picker` target Android API 24+ and iOS 13+; Android `minSdk` is set by the bootstrap script.

The workspace contains source and native permission snippets, not Flutter-generated Gradle/Xcode wrapper files. With Flutter installed, run:

```bash
chmod +x bootstrap.sh
./bootstrap.sh ../minitok_app
cd ../minitok_app
flutter run
```

Build/test on a phone with local gallery videos:

```bash
flutter run --release
flutter build apk --release
flutter analyze
```

The script generates the Android/iOS Flutter shell, copies in the app code, brands the launcher as MiniTok, applies gallery permissions and the iOS photo-library description, sets Android `minSdk` to 24, and runs `flutter pub get`.

## Native permission notes

- Android 13+: `READ_MEDIA_IMAGES` and `READ_MEDIA_VIDEO` are included for `photo_manager`.
- Android 14+: `READ_MEDIA_VISUAL_USER_SELECTED` supports partial media access.
- Android 12 and earlier: `READ_EXTERNAL_STORAGE` is capped at API 32.
- iOS: `NSPhotoLibraryUsageDescription` is included. The image picker uses the system photo picker; no camera permission is requested.
- **Do not add `INTERNET`** for this app. Sharing uses the phone's native share sheet, but the app itself does not upload or fetch media.

`permission_handler` is intentionally omitted: `photo_manager` requests/checks full and limited gallery access, avoiding a second permission source.

## Local storage

`shared_preferences` stores small local metadata (profile JSON, favorite/hidden asset IDs, feed settings, and resume position). Profile pictures are copied into the app's private support directory. Video files remain in the device gallery and are never modified by the hide action.

## Project layout

```text
lib/
├── main.dart
├── models/
│   ├── creator_profile.dart
│   └── video_item.dart
├── providers/feed_provider.dart
├── screens/
│   ├── creator_profile_screen.dart
│   ├── favorites_screen.dart
│   ├── home_screen.dart
│   ├── permission_screen.dart
│   ├── profile_editor_screen.dart
│   ├── profiles_screen.dart
│   ├── search_screen.dart
│   ├── video_collection_screen.dart
│   └── video_selection_screen.dart
├── services/
│   ├── local_store.dart
│   ├── media_service.dart
│   └── share_service.dart
└── widgets/
    ├── action_rail.dart
    ├── progress_bar.dart
    ├── video_grid.dart
    ├── video_page.dart
    └── video_thumbnail.dart
```

## Notes / MVP limits

- Shuffle randomizes loaded pages and future batches; very large libraries remain paged to limit memory.
- Video compatibility depends on the device's native player/codec support.
- Profile assignments are local metadata. A video is assigned to one creator profile at a time, but still appears in For You.
- This workspace did not have Flutter/Dart installed, so an APK and `flutter analyze` output were not produced here.
