# Sort Sprint

A standalone Apple Watch sorting game. Flick each item toward the edge that matches its category; the rule changes every round.

## Requirements

- macOS 26.6 or later on Apple silicon, Xcode 27.0 or later, the watchOS 27 simulator runtime.
- If `xcode-select -p` prints the Command Line Tools path, either run `sudo xcode-select -s /Applications/Xcode.app` once or rely on the scripts, which set `DEVELOPER_DIR` themselves.

## If the watchOS simulator runtime will not register

On macOS 27.0 the downloaded watchOS 27 runtime can sit in `xcrun simctl runtime list` as Ready while `xcrun simctl list runtimes` stays empty and `xcrun simctl runtime verify <id>` reports "a sealed resource is missing or invalid". The download itself is fine; the cryptex mount is what fails. Workaround that needs no reboot:

```bash
xcodebuild -downloadPlatform watchOS -exportPath /tmp/watch-runtime
hdiutil attach /tmp/watch-runtime/*.exportedBundle/Restore/*.dmg -mountpoint /tmp/watch-runtime/mnt -nobrowse -readonly
ditto "/tmp/watch-runtime/mnt/Library/Developer/CoreSimulator/Profiles/Runtimes/watchOS 27.0.simruntime" ~/Library/Developer/CoreSimulator/Profiles/Runtimes/"watchOS 27.0.simruntime"
hdiutil detach /tmp/watch-runtime/mnt
killall -9 com.apple.CoreSimulator.CoreSimulatorService
```

CoreSimulator scans that user-level folder for classic runtime bundles, so the runtime then appears and devices can be created with `xcrun simctl create`.

## Layout

- `Packages/SwipeSortEngine`: all game rules as pure Swift, tested on macOS.
- `WatchGame`: the watchOS app (SwiftUI, SwiftData, WidgetKit).
- `WatchGameContainer`: the empty iOS container Apple requires for watch-only apps.
- `docs/superpowers`: design spec and implementation plan.

## Commands

- `Scripts/engine-test.sh`: engine unit tests.
- `Scripts/build.sh`: build the watch app for the simulator.
- `Scripts/test.sh`: watch app unit tests on a simulator (`WATCH_SIM` overrides the device name).
- `Scripts/screenshots.sh`: home-screen screenshots on every watch size.
- `python3 Tools/generate_sounds.py`, `python3 Tools/generate_icon.py`: regenerate placeholder assets.

## Release

Archive the `WatchGameContainer` scheme, set `DEVELOPMENT_TEAM` in the project (or sign in to Xcode), and upload through Organizer. Bundle identifiers are `com.pynto.sortsprint` (container) and `com.pynto.sortsprint.watchkitapp` (watch app).
