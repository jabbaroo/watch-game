#!/bin/zsh
set -euo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$(dirname "$0")/.."
xcodebuild -project WatchGame.xcodeproj -scheme WatchGame \
  -destination 'generic/platform=watchOS Simulator' \
  -derivedDataPath .build/DerivedData \
  -quiet CODE_SIGNING_ALLOWED=NO build "$@"
echo "BUILD OK"
