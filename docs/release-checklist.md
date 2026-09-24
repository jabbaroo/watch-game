# Release checklist

## Tests
- [ ] `Scripts/engine-test.sh` and `Scripts/test.sh` pass (unit and UI).

## Simulator layout pass
- [ ] `Scripts/screenshots.sh` runs clean on 40, 41, 42, 44, 45, 46 and 49 mm.
- [ ] Play screen on 41 mm with Tap to sort on: no label overlaps the item; every label is at least 44 pt tall.

## Hardware pass (one watch per size class if possible)
- [ ] Flicks starting near the left edge do not trigger back navigation; flicks near top and bottom do not open system surfaces.
- [ ] Ambient audio: sounds mix with a playing podcast; Silent Mode mutes them; haptics still fire.
- [ ] Wrist down mid-round pauses; raising the wrist shows Paused; Resume continues with the ring where it was.
- [ ] Double Tap pauses and resumes on Series 9 or later.
- [ ] Reduce Motion: no fly-off, no confetti, crossfades only.
- [ ] VoiceOver: every screen navigable; the item reads its category; custom actions sort it; Tap to sort is forced on.
- [ ] Tap to sort mode: all four labels tappable, swipes still work.
- [ ] Full 8-round run reaches Results with the breakdown; History shows the run; daily streak increments the next day.
- [ ] Widget shows today's status; tapping it opens the daily when no run is in progress.

## App Store Connect
- [ ] Set `DEVELOPMENT_TEAM` in the project or sign in to Xcode; bundle ids registered with the App Group capability.
- [ ] Replace the placeholder icon with an Icon Composer icon; replace placeholder sounds if designed ones exist.
- [ ] Archive the `WatchGameContainer` scheme and upload with Organizer.
- [ ] Privacy: no data collected; privacy manifest present in the watch app.
- [ ] Age rating 4+; accessibility nutrition label: VoiceOver, Reduce Motion, Differentiate Without Colour Alone, Sufficient Contrast.
- [ ] Export compliance: no encryption beyond the OS; answer "No" when asked.
- [ ] Screenshots for every required watch size; category Games, subcategory Puzzle; price tier set.
- [ ] TestFlight build installed on a real watch and the hardware pass above completed.
