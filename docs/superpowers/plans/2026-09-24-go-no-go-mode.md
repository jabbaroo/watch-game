# Go, No-Go Mode Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the go, no-go mode from spec section 13.2: hold items that must be left alone, false alarms that cost a life, and a false-alarm count on Results.

**Architecture:** The pack gains a hold probability, the item sequencer draws a hold flag per item, the engine resolves a hold item's window closing as a correct non-response (`ItemOutcome.held`) and a flick as `falseAlarm`, and the statistics count holds and false alarms. The app draws the hold mark, animates the two new outcomes, captions the round intro, and shows the false-alarm row.

**Tech Stack:** As for v1.

---

### Task 1: Engine

**Files:** `ContentPack.swift` (holdProbability with custom Codable and validation), `ItemSequencer.swift` (hold draw), `RunEvents.swift` (`ActiveItem.isHold`, `ItemOutcome.held` and `.falseAlarm`), `Results.swift` (`ItemResult.hold`, decoding without the key), `ScoringRules.swift` (`pointsForHold`), `RunState.swift` (hold resolution), `RunStatistics.swift` (holdCount, falseAlarmCount, falseAlarmRate, false alarms excluded from wrong swipes and confusion pairs). Tests in `ItemSequencerTests`, `ContentPackTests`, `ResultsTests` and the new `RunStateHoldTests`.

- [x] **Step 1:** Tests for the hold draw rate, the pack field, legacy decoding, holding, false alarms and statistics.
- [x] **Step 2:** Implement; `Scripts/engine-test.sh` passes (87 tests).
- [x] **Step 3:** Commit.

### Task 2: App

**Files:** `HistoryModels.swift` (hold column), `ItemView.swift` (dot), `PlayView.swift` (label, outcomes), `RoundIntroView.swift` (caption), `StatisticsSections.swift` (row), `Tools/generate_gonogo_pack.py` and `WatchGame/Resources/Packs/gonogo.pack.json`, `Localizable.xcstrings`, tests in `PackLoaderTests`, `HistoryStoreTests` and the UI capture test.

- [x] **Step 1:** Tests: the pack loads with a 0.25 hold probability; a held item round-trips through SwiftData; a UI capture of a go, no-go round.
- [x] **Step 2:** Implement; `Scripts/build.sh` and `Scripts/test.sh` pass.
- [x] **Step 3:** Commit and push; install on the 46 mm simulator.
