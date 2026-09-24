import AppIntents

struct StartDailyChallengeIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Daily Challenge"
    static let description = IntentDescription("Opens Swipe Sort and starts today's challenge.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        LaunchRequests.shared.requestDaily()
        return .result()
    }
}

struct WatchGameShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartDailyChallengeIntent(),
            phrases: ["Start today's \(.applicationName) challenge", "Play the \(.applicationName) daily"],
            shortTitle: "Daily challenge",
            systemImageName: "calendar"
        )
    }
}
