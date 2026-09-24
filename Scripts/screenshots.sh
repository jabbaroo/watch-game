#!/bin/zsh
# Builds once, then installs and screenshots the app on every watch size in the simulator.
set -euo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$(dirname "$0")/.."
OUT=docs/screenshots
mkdir -p "$OUT"
DEVICES=("Apple Watch SE 3 (40mm)" "Apple Watch Series 9 (41mm)" "Apple Watch Series 11 (42mm)" "Apple Watch SE 3 (44mm)" "Apple Watch Series 9 (45mm)" "Apple Watch Series 11 (46mm)" "Apple Watch Ultra 3 (49mm)")
xcodebuild -project WatchGame.xcodeproj -scheme WatchGame -destination 'generic/platform=watchOS Simulator' \
  -derivedDataPath .build/DerivedData -quiet CODE_SIGNING_ALLOWED=NO build
APP=.build/DerivedData/Build/Products/Debug-watchsimulator/WatchGame.app
for device in "${DEVICES[@]}"; do
  udid=$(xcrun simctl list devices available | grep "$device (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/' || true)
  if [ -z "$udid" ]; then echo "skip: $device not available"; continue; fi
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl install "$udid" "$APP"
  xcrun simctl launch "$udid" com.pynto.sortsprint.watchkitapp >/dev/null
  sleep 3
  slug=$(echo "$device" | tr -cd '[:alnum:]' )
  xcrun simctl io "$udid" screenshot "$OUT/$slug-home.png" >/dev/null
  echo "captured $OUT/$slug-home.png"
  xcrun simctl shutdown "$udid" >/dev/null || true
done
