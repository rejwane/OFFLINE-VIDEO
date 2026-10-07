#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-"${SOURCE_DIR}/../offline_video_feed_app"}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK not found. Install Flutter 3.44+ and rerun this script." >&2
  exit 1
fi

if [[ -e "$TARGET_DIR" ]]; then
  echo "Target already exists: $TARGET_DIR" >&2
  echo "Choose a new path, for example: ./bootstrap.sh ../my_offline_feed" >&2
  exit 1
fi

flutter create --platforms=android,ios --project-name offline_video_feed "$TARGET_DIR"
cp -R "$SOURCE_DIR/lib/." "$TARGET_DIR/lib/"
cp "$SOURCE_DIR/pubspec.yaml" "$TARGET_DIR/pubspec.yaml"
cp "$SOURCE_DIR/analysis_options.yaml" "$TARGET_DIR/analysis_options.yaml"
cp "$SOURCE_DIR/README.md" "$TARGET_DIR/README.md"

python3 - "$TARGET_DIR" <<'PY'
from pathlib import Path
import plistlib
import re
import sys

root = Path(sys.argv[1])

manifest = root / "android/app/src/main/AndroidManifest.xml"
text = manifest.read_text()
text = re.sub(r'android:label="[^"]+"', 'android:label="MiniTok"', text, count=1)
permissions = [
    '<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />',
    '<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />',
    '<uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" />',
    '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />',
]
missing = [line for line in permissions if line.split('android:name="')[1].split('"')[0] not in text]
application_start = text.find("<application")
if application_start < 0:
    raise SystemExit(f"Could not find <application> in {manifest}")
if missing:
    line_start = text.rfind("\n", 0, application_start) + 1
    application_indent = text[line_start:application_start]
    additions = "".join(f"{application_indent}{line}\n" for line in missing)
    text = text[:line_start] + additions + text[line_start:]
manifest.write_text(text)

info_plist = root / "ios/Runner/Info.plist"
with info_plist.open("rb") as plist_file:
    plist_data = plistlib.load(plist_file)
plist_data["CFBundleDisplayName"] = "MiniTok"
plist_data.setdefault(
    "NSPhotoLibraryUsageDescription",
    "Allow access to your video library so local videos can play in the feed.",
)
with info_plist.open("wb") as plist_file:
    plistlib.dump(plist_data, plist_file, fmt=plistlib.FMT_XML, sort_keys=False)

# video_player 2.14.x requires Android API 24 or newer.
gradle_files = [
    root / "android/app/build.gradle.kts",
    root / "android/app/build.gradle",
]
for gradle_file in gradle_files:
    if not gradle_file.exists():
        continue
    gradle_text = gradle_file.read_text()
    updated, count = re.subn(
        r"(?m)^(\s*minSdk(?:Version)?\s*(?:=\s*)?)(?:flutter\.minSdkVersion|\d+)",
        r"\g<1>24",
        gradle_text,
        count=1,
    )
    if count:
        gradle_file.write_text(updated)
        break
else:
    print("WARNING: Set Android minSdk to 24 in android/app/build.gradle(.kts).")
PY

(
  cd "$TARGET_DIR"
  flutter pub get
)

echo
echo "Project created at: $TARGET_DIR"
echo "Run it with: cd \"$TARGET_DIR\" && flutter run"
