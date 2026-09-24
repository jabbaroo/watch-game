# Swipe Sort

A standalone Apple Watch sorting game. Flick each item toward the edge that matches its category; the rule changes every round.

## Requirements

- macOS 26.6 or later on Apple silicon, Xcode 27.0 or later, the watchOS 27 simulator runtime.
- If `xcode-select -p` prints the Command Line Tools path, either run `sudo xcode-select -s /Applications/Xcode.app` once or rely on the scripts, which set `DEVELOPER_DIR` themselves.

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

Archive the `WatchGameContainer` scheme, set `DEVELOPMENT_TEAM` in the project (or sign in to Xcode), and upload through Organizer. Bundle identifiers are `com.pynto.swipesort` (container) and `com.pynto.swipesort.watchkitapp` (watch app).
