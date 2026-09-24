#!/bin/zsh
set -euo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$(dirname "$0")/.."
DEVICE="${WATCH_SIM:-Apple Watch Series 11 (46mm)}"
if ! xcrun simctl list devices available | grep -q "$DEVICE ("; then
  DEVICE=$(xcrun simctl list devices available | grep -m1 -E '^\s+Apple Watch' | sed -E 's/^\s+(.*) \([0-9A-F-]{36}\).*/\1/')
  [[ -n "$DEVICE" ]] || { echo "No watchOS simulator available; create one with xcrun simctl create" >&2; exit 1; }
  echo "using simulator: $DEVICE"
fi
xcodebuild -project WatchGame.xcodeproj -scheme WatchGame \
  -destination "platform=watchOS Simulator,name=${DEVICE}" \
  -derivedDataPath .build/DerivedData \
  -quiet CODE_SIGNING_ALLOWED=NO test "$@"
echo "TESTS OK"
