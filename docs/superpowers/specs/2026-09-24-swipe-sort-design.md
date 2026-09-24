# Swipe Sort: watchOS sorting game design

Date: 2026-09-24
Status: approved (revision 5; timing tuned from first play-testing on 2026-09-24)
Working title: Swipe Sort (project and target name `WatchGame`; display name is configurable and will change when a final name is chosen)

## 1. Summary

Swipe Sort is a standalone Apple Watch game. An item appears in the centre of the screen and the player flicks it toward the screen edge that matches its category. Each round has one sorting rule (for example "sort by colour") and a fixed mapping of categories to edges. Between rounds the rule changes and the edge mapping reshuffles. Re-learning the mapping after a rule switch is the cognitive hook; reaction speed under a shrinking time window is the arcade hook.

A run is 8 rounds of 40 seconds. Players have 3 lives, lose one per error, and earn one back for a perfect round. Every item answered is recorded so the results screen can break errors down, and history charts show how the player changes over time.

Decisions already made with the product owner:

| Decision | Choice |
|---|---|
| Toolchain | Xcode 27, Swift 6.4, watchOS 27 SDK, minimum deployment watchOS 26 |
| Run shape | Fixed 8 rounds, final results screen |
| Lives | 3 per run, one earned back per perfect round, capped at 3 |
| Data | Local only, no iCloud sync in version 1 |
| Business model | Paid up front, no in-app purchases, no ads |
| Source control | https://github.com/jabbaroo/watch-game, branch `main` |
| Content | Version 1 ships one pack (shapes and colours). Image packs will follow and the pack format must support them from day one. |

## 2. Goals and non-goals

Goals for version 1:

- A complete, polished, App Store ready watch-only game.
- Sessions of roughly 5 to 7 minutes for a full run, with every run kept in the run list even when it ends early.
- Feedback that feels rewarding on the wrist: haptics first, sound and visuals layered on top.
- Deterministic, unit-tested game logic separated from the SwiftUI layer.
- A content pack format that supports shapes drawn in code today and bundled images tomorrow.
- Accessibility and App Review readiness designed in, not bolted on.

Non-goals for version 1 (explicitly deferred):

- iCloud sync, Game Center, in-app purchases, an iPhone companion app.
- Stroop, conditional, mirror or memory round variants.
- Emoji or SF Symbol visuals in packs. The format has room for them but version 1 renders only code-drawn shapes and bundled images.
- Resuming a run after the app process is terminated. A run survives wrist-down and backgrounding because the process is normally kept alive; if the process is killed mid-run, completed rounds are kept and the run is marked incomplete.
- Any network access. The app makes no network calls.

## 3. Gameplay

### 3.1 Run structure

- A run is 8 rounds. Each round lasts 40 seconds of play time. Paused time does not count.
- Before every round, an interstitial shows the round number, the rule ("Sort by colour"), the edge mapping, lives and score. It auto-starts after 2.5 seconds with a visible countdown ring; tapping starts it immediately. The countdown stops while the scene is inactive or the display luminance is reduced and restarts from 2.5 seconds when the scene becomes active again.
- Rounds rotate through the pack's dimensions in order, starting with the first. With the version 1 pack this alternates colour, shape, colour, shape and so on.
- Category count ramps: rounds 1 and 2 use 2 categories, rounds 3 and 4 use 3, rounds 5 to 8 use 4. If a dimension has fewer values than the ramp asks for, the count is capped at the number of values.
- Active categories are drawn at random from the dimension's values each round. Edge assignment is random each round. With 2 categories the edges are left and right; with 3 they are left, right and up; with 4 all four edges are used.
- The run ends after round 8, or immediately when lives reach zero. Both paths lead to the results screen and both count as completed runs. A run that reaches zero lives mid-round keeps that round's results (flagged as cut short) so its errors still feed the breakdown, but the round does not count toward "rounds completed".
- Quitting from the pause screen discards the current round's items, keeps the rounds already finished, marks the run incomplete and returns to Home without a results screen.

### 3.2 Items

- Items appear one at a time in the centre of the screen. After an item is resolved there is a 250 millisecond transition before the next appears.
- Each item has a value on every dimension of the pack. Its value on the active dimension is one of the active categories. Its values on the other dimensions come from the selected item, so the inactive dimension creates interference.
- The same target category never appears more than twice in a row.
- Item selection is two steps: pick the target category (respecting the two-in-a-row rule), then pick uniformly among the pack's items whose value on the active dimension is that category. A pack therefore never needs every attribute combination.
- Every item has a time window, fixed when the item appears. If the player has not answered when the window closes, the item times out.
- Each round has a base window: 2.0, 1.9, 1.75, 1.6, 1.45, 1.3, 1.15 and 1.0 seconds for rounds 1 to 8. Early rounds are comfortable; by the last rounds the player has to be quick. The current streak trims the window further: 0.05 seconds for every 5 consecutive correct answers, up to 0.2 seconds. The trim is a function of the streak at the moment the item appears, so an error resets the streak and the next item gets the round's untrimmed window. The window never drops below 0.85 seconds.
- The first item of every round gets a grace of 1 extra second on top of its window, so the cost of a rule switch is paid in reaction time rather than in a life. Play-testing showed the first item after a switch was the one most often lost to a timeout.
- When the round clock expires, an item that is still on screen is cancelled without penalty and is not recorded.

### 3.3 Lives

- A run starts with 3 lives.
- A wrong swipe or a timeout costs one life.
- A perfect round (at least one item, no errors, not cut short) earns one life back, capped at 3.
- At zero lives the run ends immediately.

### 3.4 Scoring

- Correct answer: 100 points multiplied by the streak multiplier, plus a speed bonus.
- Streak is the number of consecutive correct answers in the current round, including the current one. It resets to zero at the start of each round and after any error.
- Multiplier: streak 1 to 4 is 1x, 5 to 9 is 2x, 10 to 14 is 3x, 15 and above is 4x.
- Streak milestone: the moment the streak reaches a multiple of 5. At a milestone the multiplier steps up (until it reaches 4x), the next item's window trims, the success haptic replaces the click, and the multiplier badge pops. Everything streak-related aligns on multiples of 5.
- Speed bonus: 50 points scaled by the fraction of the window remaining when the answer arrived, rounded to the nearest integer.
- Errors score zero.
- Perfect round bonus: 500 points, included in that round's score.
- Run score is the sum of round scores. Best score is the highest score among completed runs in history.

### 3.5 What is recorded

The engine produces value types; the app persists them.

- `ItemResult`: round index, item index, the active dimension, the item's value on every dimension, the expected category, the answered category (nil for a timeout), whether it was correct, whether it timed out, reaction time (nil for a timeout), the window, and points awarded.
- `RoundResult`: index, dimension, category count, whether it was perfect, whether it was cut short, round score (including any perfect bonus), and its item results.
- `RunSummary`: seed, pack identifier, final score, lives remaining, end reason, and its round results. End reasons are completed all rounds, out of lives, quit, and abandoned; the engine never produces abandoned, the app sets it for runs interrupted by a process kill. Rounds completed is the count of rounds not cut short. A run is complete only when its end reason is completed all rounds or out of lives.

The app adds start and end timestamps, whether the run was a daily challenge and for which day.

### 3.6 Statistics derived from results

- Accuracy: correct items divided by resolved items, nil when nothing was resolved.
- Error split: wrong swipes versus timeouts.
- Errors by rule: error count and rate per dimension.
- Confusion pairs: counts of (expected category, answered category) for wrong swipes, shown as the top three.
- Mean reaction time over correct items, nil when there are none.
- Switch cost: for each round with at least 6 correct items, the mean reaction time of the first 3 correct items minus the mean reaction time of the remaining correct items. The run's switch cost is the mean across qualifying rounds, or nil if no round qualifies.
- Sharpest time of day (history only): completed runs are bucketed by their start time into four local-time buckets (morning 05:00 to 11:59, afternoon 12:00 to 16:59, evening 17:00 to 21:59, night otherwise). Each run contributes its mean reaction time, and runs with no mean reaction time are left out; the bucket with the lowest mean over at least 3 runs is reported.
- All history aggregates (best score, runs played, charts, time of day, daily streak) use completed runs only. Incomplete runs appear in the run list marked as incomplete.

### 3.7 Daily challenge

- The daily challenge is a normal run whose random seed is derived from the local calendar date. Round plans and every round's item stream are derived from that seed during planning, independent of how many items the player got through in earlier rounds, so the sequence of rules, mappings and items is the same for every play of that day.
- The daily can be replayed. A calendar day is marked as played once any daily run for that day completes.
- Daily streak is the count of consecutive marked days ending today, or ending yesterday if today is not yet played.

## 4. Input

- Primary input is a flick gesture. A drag with a minimum distance of 8 points is tracked. On release, the dominant axis decides the direction. The gesture counts as an answer if the translation along the dominant axis is at least 24 points, or the predicted end translation is at least 60 points. If the two axes are within 20 percent of each other the gesture is ignored and the item stays on screen.
- A flick toward an edge that has no category in the current round is ignored, exactly like an ambiguous gesture. No life is lost and nothing is recorded. Time pressure still applies because the window keeps running.
- Gestures that begin within 14 points of any screen edge are ignored so they cannot collide with system edge gestures. Play is presented as a full screen cover, not pushed on the navigation stack, so there is no interactive back swipe to collide with.
- An item accepts one answer. After answering, the item animates off screen in the chosen direction.
- Tap to sort (setting, off by default): the edge labels become tappable targets with hit areas of at least 44 by 44 points. Swiping still works when tap to sort is on. When VoiceOver is running, tap to sort is forced on and each active edge is also exposed as an accessibility custom action on the item.
- Double Tap (Series 9 and later): mapped to pause during play and resume while paused, through the SwiftUI hand gesture shortcut on the pause and resume buttons.
- The Digital Crown is not used in version 1.

## 5. Feedback

### 5.0 Feedback cues

The engine decides when feedback happens by emitting feedback effects. Each effect carries exactly one cue, and one event may emit several effects (a perfect round emits `perfectRound` and, when a life is restored, `lifeEarned`). The haptic and sound services each map every cue to what it feels and sounds like. The cue set is:

- `correct(streak)`: a correct answer whose streak is not a multiple of 5.
- `streakMilestone(streak)`: a correct answer whose streak is a multiple of 5. Replaces `correct` for that answer.
- `wrong`: a flick to a mapped edge with the wrong category.
- `timedOut`: the item window closed without an answer.
- `lifeEarned`: a perfect round restored a life.
- `perfectRound`: a round ended perfect, whether or not a life was earned.
- `roundStarted`: the first item of a round appeared.
- `runEnded`: the run finished for any reason except quit.

### 5.1 Haptics

Haptics are the primary reward channel and are on by default. The mapping lives only in the `HapticsService`:

| Cue | Haptic |
|---|---|
| correct | click |
| streakMilestone | success |
| wrong, timedOut | failure |
| lifeEarned | direction up |
| roundStarted | start |
| runEnded | stop |
| perfectRound | none; the life-earned haptic follows in the common case, and at full lives the fanfare carries it |

### 5.2 Sound

Sound is on by default but never required to play. The audio session uses the ambient category so it mixes with whatever the player is listening to and respects Silent Mode; this behaviour is verified on hardware in the first hardware pass. Sounds are short bundled files (the correct sound under 150 milliseconds, everything else 500 or under) played through an `AVAudioEngine` player node. watchOS has no time-pitch audio unit, so the correct sound ships as 19 pre-rendered variants, one per semitone from 0 to 18. Version 1 ships synthesised placeholder files generated by a script in `Tools/` so they can be replaced by designed assets without code changes; a designed correct sound must be supplied as the same 19 variants.

| Cue | Sound |
|---|---|
| correct(streak), streakMilestone(streak) | the correct sound variant for (streak minus 1) divided by 2 semitones, capped at 18, so the pitch keeps climbing through a whole round of about 35 items |
| wrong | low thud |
| timedOut | whoosh |
| roundStarted | ding |
| perfectRound | short fanfare |
| runEnded | sting |
| lifeEarned | none |

Because the streak resets on any error, the pitch resets with it.

### 5.3 Visual effects

- Correct: the item flies off toward the chosen edge with a slight scale-up, the matching edge label pulses, the score ticks up.
- Wrong: the item shakes horizontally, the screen edge flashes briefly, a life indicator empties.
- Timeout: the item dissolves in place.
- Streak milestone: the multiplier badge pops.
- Perfect round: a particle burst of at most 40 particles for one second, drawn with `Canvas`, on the next interstitial, or on the results screen when the perfect round was the last one.
- Reduce Motion: movement is replaced by opacity crossfades and the particle burst is skipped.

## 6. Screens

Navigation is a `NavigationStack` rooted at Home. Play is presented as a full screen cover with no navigation bar.

1. Home: title, Play, Daily challenge (shows today's status and the streak), History, Settings. Version 1 always plays the built-in pack; a pack picker arrives with the first image pack.
2. Round interstitial: round number, rule, edge mapping preview, lives, score, countdown ring. Tap to start now.
3. Play: a thin round-clock bar along the top, lives and score in the top corners, the item in the centre with a shrinking ring, category labels at the active edges. A small pause button sits in a bottom corner, clear of the down-edge label, and also carries the Double Tap shortcut.
4. Paused: Resume (Double Tap shortcut) and Quit run with a confirmation. Quit returns to Home.
5. Results: a headline saying why the run ended ("Run complete", "Out of lives in round 3", or "Incomplete run"), then the score with a best-ever badge, accuracy, rounds completed, lives remaining, then error split, errors by rule, top confusion pairs, mean reaction time, switch cost. Buttons: Play again, Home. Play again keeps the mode: after a daily it replays the daily, after free play it starts a new random seed.
6. History: tiles for best score, runs played and daily streak; Swift Charts lines for score, mean reaction time and switch cost over the last 30 completed runs; sharpest time of day; a list of runs that opens the results view for that run.
7. Settings: Sounds, Haptics, Tap to sort, Colour hints, Reset history (with confirmation), About.

## 7. Content packs

### 7.1 Format

```
ContentPack
  id: String                       // "shapes-colours"
  nameKey: String                  // String Catalog key
  dimensions: [Dimension]
  items: [Item]

Dimension
  id: String                       // "colour"
  nameKey: String                  // "dimension.colour"
  values: [CategoryValue]

CategoryValue
  id: String                       // "red"
  labelKey: String                 // "colour.red"
  hintKey: String?                 // key for a one-character hint shown when Colour hints is on

Item
  id: String
  attributes: [String: String]     // dimension id to value id
  visual: Visual

Visual (enum, JSON object with a "type" discriminator)
  shape(kind: circle | square | triangle | star, colour: hex)
  image(assetName: String)         // asset catalog image set, for image packs
```

### 7.2 Validation

A pack is valid when all of the following hold. The engine's `validate()` throws the first failure it finds.

- At least one dimension and at least one item.
- Dimension ids, value ids within a dimension, and item ids are unique.
- Every dimension has at least 2 values.
- Every item has an attribute for every dimension, and every attribute value is a declared value id of that dimension.
- Every value of every dimension is used by at least one item, so an active category always has something to show.
- App-level, in the app's unit tests: every `image` asset name resolves in the asset catalog, and every `nameKey`, `labelKey` and `hintKey` exists in the String Catalog.

### 7.3 Version 1 pack and future packs

The version 1 pack "Shapes and Colours" is defined in code in the engine as `ContentPack.shapesAndColours`: colour values red, yellow, green, blue; shape values circle, square, triangle, star; 16 items, one per combination, rendered as vector shapes. Colours use the Okabe-Ito palette so they stay distinguishable under red-green colour vision deficiency: red `#D55E00`, yellow `#F0E442`, green `#009E73`, blue `#0072B2`.

Additional packs are JSON files in the app bundle under `Packs/`. The loader decodes and validates every bundled JSON pack at launch, skips any that fail with a log message, and always lists the built-in shapes pack first. An app unit test decodes and validates every bundled JSON pack, plus a test-target fixture pack that includes an `image` visual, so the JSON path is exercised before any image pack ships and a bad pack fails the build. Adding an image pack means adding a JSON file, image sets and String Catalog entries; no code changes. Round planning caps category counts at the number of values a dimension has, so a pack with a 3-value dimension still works.

## 8. Architecture

### 8.1 Modules

`Packages/SwipeSortEngine` is a local Swift package with no UI dependencies, buildable and testable on macOS with `swift test`:

- `ContentPack` and its decoding and validation.
- `RunConfiguration`: rounds, round duration, window schedule, lives, scoring constants. One place to tune.
- `RoundPlanner`: given a pack, a configuration and a seeded random generator, produces the 8 `RoundPlan`s (dimension, active categories, edge mapping, and a per-round item seed drawn during planning).
- `ItemSequencer`: produces the item stream for a round from its own generator seeded with the plan's item seed, enforcing the no-more-than-two-in-a-row rule.
- `RunState`: a value type with `mutating func apply(_ event: RunEvent, at now: Duration) -> [RunEffect]`. Deadlines are applied before the event, in chronological order: an answer arriving at or after the item deadline resolves as a timeout, and any event arriving at or after the round clock's expiry ends the round first (with the item cancelled), so correctness never depends on tick ordering. Events: start run, start round, answer(edge), tick, pause, resume, quit. Effects: round intro, round started, item shown, item resolved (with its `ItemResult` and outcome), lives changed, score changed, round ended (with its `RoundResult`), run ended (with its `RunSummary`), feedback(cue), and wake(at:). `tick` is the generic "time may have passed" event: it handles item timeouts, the end of the inter-item transition and round clock expiry. `wake(at:)` tells the driver the next time it must send a tick, always the earliest of the item deadline, the transition end and the round deadline. All timing is computed from the `now` passed in; the engine owns no clock.
- `ScoringRules`: pure functions for points and multipliers.
- `RunStatistics`: derives the section 3.6 per-run statistics from `RoundResult`s.
- `DailySeed`: date to seed.
- `SeededGenerator`: a deterministic `RandomNumberGenerator` (SplitMix64).

`WatchGame` (watchOS app target):

- `App`: entry point, scene phase handling, model container setup.
- `Game/GameSession`: an `@Observable @MainActor` class that owns a `RunState`, drives it from a `ContinuousClock`, maps effects to feedback and persistence, and exposes view state. It pauses on scene phase change and when the display luminance is reduced; the Paused screen then waits for an explicit Resume (tap or Double Tap), and deadlines are rebased at that moment.
- `Feedback/HapticsService` and `Feedback/SoundService`: protocols that take a feedback cue, with watch implementations and no-op implementations for previews and tests.
- `Persistence`: SwiftData models `RunEntry`, `RoundEntry`, `ItemEntry` and a `HistoryStore` that inserts entries from engine results, converts entries back to `RoundResult`s for `RunStatistics`, and answers history queries. Models use optional relationships and default values so CloudKit sync can be enabled later without a migration. At launch the store marks any run entry with no end time as abandoned (end reason abandoned, incomplete).
- `Packs/PackLoader`: built-in pack plus bundled JSON packs.
- `Views`: one folder per screen.
- `Resources`: String Catalog, asset catalog, Icon Composer icon, sounds, privacy manifest.

`WatchGameWidget` (widget extension), sequenced as the last milestone after a full run plays end to end:

- Shows today's daily status and the daily streak in the Smart Stack (rectangular and circular families) and deep links to the daily challenge with the URL `swipesort://daily`.
- Data: the app writes a `WidgetSummary` JSON file (`dailyKey` as the local calendar day in `yyyy-MM-dd`, `dailyPlayedToday`, `dailyStreak`, `usualPlayHour` optional) to the App Group container `group.com.pynto.swipesort` at launch, at run end and after Reset history, then reloads widget timelines. The widget never opens the SwiftData store.
- Display state is derived from the file's `dailyKey` against the current local date, never taken verbatim: if `dailyKey` is today, show the file's values; if `dailyKey` is yesterday and `dailyPlayedToday` is true, show unplayed today with the file's streak; otherwise show unplayed today with a streak of zero.
- Timeline: an entry for now and an entry at the next local midnight, both computed with the rule above for their own dates, with reload policy at end so the provider is queried again after midnight. The status stays correct across the day boundary without the app running.
- Deep link: the app handles `onOpenURL`. If no run is in progress it starts the daily; if a run is in progress the link is ignored.
- Relevance: `usualPlayHour` is the most common start hour among the last 30 completed runs when there are at least 3; the app registers a RelevanceKit date-based context for a one-hour interval around it, or none.
- Error handling: if the App Group container is unavailable the app skips the write and logs; the widget shows the default "Play today's challenge" state.

`Tools/`: the sound generator script.

### 8.2 Data flow

1. Home taps Play. `GameSession` loads the pack, builds a configuration and a seed (random, or daily), and creates a `RunState`.
2. The session sends `startRun`, shows the round intro from the resulting effect, and sends `startRound` when the 2.5 second countdown ends or the player taps.
3. A timer task sleeps until the time in the latest `wake(at:)` effect, then sends `tick`. A gesture sends `answer(edge)`. Each call returns effects; the session applies them to view state, feedback services and the history store.
4. Completed rounds are written to the store as they finish. When the run ends the run entry is finalised and the results view reads from the store.
5. History reads only from the store.

### 8.3 Error handling

- Pack decoding failure: an app unit test fails the build; at runtime the loader skips the bad JSON pack, logs, and the built-in pack remains available.
- Audio session or engine failure: logged, sound disabled for the session, gameplay unaffected.
- SwiftData container failure: fall back to an in-memory container so the game still plays, and show a one-time notice on History that history is unavailable.
- App Group container unavailable: widget summary write skipped and logged.
- Ambiguous gesture or flick to an unmapped edge: ignored, no penalty.
- Scene goes inactive during play: engine paused, deadlines rebased on resume. Time paused is not counted.
- Process killed mid-run: the run entry is marked abandoned at next launch and excluded from aggregates.

### 8.4 Concurrency

Swift 6 language mode with strict concurrency. The engine is `Sendable` value types. `GameSession`, feedback services and the model container are main-actor isolated. The timer loop is a structured `Task` owned by the session and cancelled on pause, quit and deinit.

## 9. Testing

- Engine (Swift Testing, run on macOS): planner ramps and caps, edge assignment sizes, window schedule and floor, no-more-than-two-in-a-row, scoring table, streak reset per round, life loss and earn-back with cap, run ends at zero lives with the round flagged cut short, timeout handling, round clock cancels the in-flight item, flick to an unmapped edge is ignored, pause and resume rebasing, quit produces an incomplete summary, statistics including switch cost and confusion pairs, daily seed stability for the same local date, and full-run item sequence determinism regardless of how many items each round consumed.
- App (watchOS simulator): bundled pack decoding and asset resolution including a fixture pack with an image visual, `HistoryStore` with an in-memory container, incomplete-run marking, daily streak across a day boundary, statistics rendering with sample data, swipe classifier maths, and one UI smoke test that launches, taps Play and sees the first item.
- Simulator layout pass on 40, 41, 42, 44, 45, 46 and 49 millimetre sizes, with tap to sort on, before the first TestFlight build.
- Manual hardware checklist before release: edge gestures, ambient audio mixing and Silent Mode, wrist-down mid-round, Reduce Motion, VoiceOver on every screen, tap-to-sort mode, Double Tap pause.

## 10. Accessibility

- Every item, edge label and control has a VoiceOver label. The item's label reads its category on the active dimension.
- With VoiceOver running, tap to sort is forced on and the item exposes one custom action per active edge.
- Colour hints setting overlays each colour's one-character hint on the item for players who cannot rely on colour alone.
- Reduce Motion is respected as described in section 5.3.
- Dynamic Type is respected on all non-play screens; the play screen uses fixed sizes for layout stability.
- Tap to sort provides a non-gesture input path.

## 11. App Store readiness

- Standalone watchOS app, paid up front. Category Games, subcategory Puzzle.
- Bundle identifier `com.pynto.swipesort` as a placeholder until the App Store Connect record is created. It is free to change until the first upload.
- Privacy manifest declares no tracking, no collected data, and required reasons for user defaults (CA92.1), file timestamps (C617.1) and system boot time used for elapsed-time measurement (35F9.1).
- Age rating 4+. Accessibility nutrition label claims: VoiceOver, Reduce Motion, Differentiate Without Colour Alone, Sufficient Contrast. Larger Text is not claimed because the play screen uses fixed type sizes.
- App icon built with Icon Composer. String Catalog for localisation with English as the base. Screenshots for each required watch size.
- No third-party dependencies.

## 12. Definition of done for version 1

- A full 8-round run plays on hardware with haptics, sound and visual feedback, and the results screen shows the section 3.6 breakdown.
- History persists across launches and charts at least the last 30 completed runs.
- Daily challenge and streak work across a change of day.
- The Smart Stack widget shows daily status and opens the daily challenge.
- All engine tests pass with `swift test`; app tests pass on the watchOS 27 simulator.
- The simulator layout pass and the manual hardware checklist pass.
- A build has been uploaded to TestFlight.

## 13. Roadmap: more cognitive modes

Principle: every mode is a variant of the one flick loop the hand already knows. New modes arrive as packs and rule variants first, and only later as a second input loop. Each mode reports one headline metric, and the History screen grows a small profile (speed, switching, inhibition, memory, attention) built from those metrics. Wording everywhere stays "mental agility" and "see how you switch, focus and remember"; the app never claims to train or improve cognition, and all data stays on the watch.

### 13.1 Stroop (first)

- Pack `stroop`, shipped as JSON, with two dimensions that share value ids: `ink` (red, yellow, green, blue) and `word` (the same four ids). Items are the 16 word-in-ink combinations; a quarter are congruent (the word in its own colour), the rest incongruent.
- A new visual, `word(textKey:colour:)`, draws a localised word in a colour. The colour-hints setting does not apply to words.
- Rounds rotate ink, word, ink, word: sorting by ink is the classic Stroop task, sorting by the word's meaning is the reverse Stroop. Category labels reuse the colour names.
- Headline metric, interference cost: mean correct reaction time on incongruent items minus congruent ones, over the whole run, shown on Results as "Interference" when there are at least 3 of each. The engine defines congruence generically as "every dimension carries the same value id", so the metric is nil for packs where ids never match.
- Home gains a mode: Play starts the last-used pack and shows its name; a "Mode" row picks between packs when more than one is installed. The daily challenge keeps using the shapes pack.
- Results and History show the pack name.

### 13.2 Go, no-go (built)

- Any pack may carry `holdProbability` (0 to 0.9, default 0). The item sequencer draws each item's hold flag from the round's own generator, so seeded runs reproduce. The go, no-go pack ships as JSON: the shapes and colours items with a hold probability of 0.25.
- A hold item shows a black dot with a white ring at its centre, and its VoiceOver label ends with "hold". The round intro adds "Hold the dotted ones" under the rule.
- Leaving a hold item until its window closes is correct: it extends the streak and scores base points times the multiplier, with no speed bonus. Flicking it is a false alarm: it costs a life and resets the streak, like a wrong swipe. A held item is neither a timeout nor a wrong swipe in the statistics.
- Metrics: false alarms out of hold items, shown on Results as "False alarms n of m"; mean reaction time is unaffected because held items have no reaction time.
- The engine records `hold` on each item result; older persisted results decode with hold false.

### 13.3 Two-back (built)

- Any pack may carry `backRamp`, a per-round depth list (0 to 3, rounds past the end reuse the last value, empty for plain sorting). The two-back pack ships as JSON: the shapes and colours items with the ramp 1, 1, 2, 2, 2, 2, 2, 2, so rounds 1 and 2 are one-back and the rest two-back.
- At depth n the first n items of a round are primers: they show with an accent-coloured ring and the caption "Remember", input on them is ignored, and their window closing is neutral (no points, no life, not recorded). The first answerable item, index n, carries the first-item grace instead of the primer.
- Every later item is judged against the category, on the active dimension, of the item shown n steps earlier. The record describes the item on screen, with the expected category taken from the earlier item. Scoring, streak and lives work as in plain sorting.
- The round intro adds "Sort the previous item" for depth 1 or "Sort the item from n back" for deeper rounds. VoiceOver reads the item on screen ("Remember, Red" for primers).
- Metric: accuracy per depth, shown on Results in a "Memory" section as "1-back accuracy" and "2-back accuracy". The round result records `backDepth`; older persisted rounds read back as depth 0.

### 13.4 Rule variants that need no new rendering

Conditional rules ("sort by colour unless it is a star, then by shape"), mirror rounds (flick away from the matching edge), fading edge labels (spatial memory), and flanker items (a centre item surrounded by distractors, selective attention).

### 13.5 More packs

Number packs (odd or even, above or below fifty), word packs (vowel or consonant first letter, real word or nonsense), and the image packs already planned (animals by habitat, fruit versus vegetables), each with two or three dimensions so the switch mechanic survives.

### 13.6 A second loop, later

Sequence recall (edges flash, repeat with flicks), which side has more (two dot clouds, flick toward the larger), crown estimation (turn the crown to match a length or count), and rhythm taps.
