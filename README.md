# APK build
## Cloud (no Flutter needed)
1. New GitHub repo, push this folder.
2. Actions tab -> "Build APK" -> run -> download artifact `offline-video-feed-apk`.
3. Unzip, install app-release.apk on phone.

## Local
flutter create . --platforms android
(add permissions from .github/workflows/build.yml to AndroidManifest.xml)
flutter pub get && flutter build apk --release
