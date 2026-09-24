# Two-Back Mode Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the two-back mode from spec section 13.3: primers that just show, answers judged against the item shown n steps earlier, and accuracy per depth on Results.

**Architecture:** The pack gains a per-round depth ramp, the planner copies the depth into each `RoundPlan`, the engine keeps the categories shown so far in a round, marks the first n items as primers (neutral, unrecorded) and computes every later item's expected category from the history. Statistics group rounds by depth.

**Tech Stack:** As for v1.

---

### Task 1: Engine

**Files:** `ContentPack.swift` (`backRamp`, `backDepth(roundIndex:)`, validation 0 to 3), `RoundPlanner.swift` (`RoundPlan.backDepth`), `RunEvents.swift` (`ActiveItem.isPrimer`, `ItemOutcome.primed`), `Results.swift` (`RoundResult.backDepth` with lenient decoding), `RunState.swift` (`shownCategories`, primers, n-back expectation, grace on the first answerable item), `RunStatistics.swift` (`accuracyByDepth`). Tests in the new `RunStateBackTests` and `ResultsTests`.

- [x] **Step 1:** Tests for the ramp, plan depths, primer neutrality, one-back and two-back expectations, grace placement and per-depth accuracy.
- [x] **Step 2:** Implement; `Scripts/engine-test.sh` passes (95 tests).
- [x] **Step 3:** Commit.

### Task 2: App

**Files:** `HistoryModels.swift` (backDepth column), `PlayView.swift` (primer ring and caption, primed outcome, VoiceOver label), `RoundIntroView.swift` (depth captions), `StatisticsSections.swift` (Memory section), `Tools/generate_nback_pack.py` and `WatchGame/Resources/Packs/nback.pack.json`, `Localizable.xcstrings`, tests in `PackLoaderTests`, `HistoryStoreTests` and the UI capture test.

- [x] **Step 1:** Tests: the pack loads with its ramp; a round's depth round-trips through SwiftData; a UI capture of a two-back round.
- [x] **Step 2:** Implement; `Scripts/build.sh` and `Scripts/test.sh` pass.
- [x] **Step 3:** Commit and push; install on the 46 mm simulator.
