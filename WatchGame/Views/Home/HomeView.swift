import SwiftUI
import SwipeSortEngine

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var isRunPresented = false
    @State private var dailyStatus = ""
    @AppStorage(AppSettings.packID) private var packID = ContentPack.shapesAndColours.id
    private let launchRequests = LaunchRequests.shared

    var body: some View {
        NavigationStack {
            List {
                Section("Games") {
                    ForEach(environment.packs) { pack in
                        Button {
                            startRun(daily: false, packID: pack.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(Localization.string(pack.nameKey))
                                        .font(.headline)
                                    if let key = pack.descriptionKey {
                                        Text(Localization.string(key))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "play.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .accessibilityIdentifier("play.\(pack.id)")
                        .accessibilityLabel(Text("Play \(Localization.string(pack.nameKey))"))
                    }
                }
                Section {
                    Button {
                        startRun(daily: true)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Daily challenge", systemImage: "calendar")
                            Text(dailyStatus)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Label("History", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle("Sort Sprint")
        }
        .fullScreenCover(isPresented: $isRunPresented, onDismiss: runDidDismiss) {
            if let session = environment.session {
                RunView(
                    session: session,
                    onPlayAgain: { startRun(daily: session.isDaily, packID: session.isDaily ? nil : session.pack.id) },
                    onDismiss: { isRunPresented = false }
                )
                .id(ObjectIdentifier(session))
                .interactiveDismissDisabled()
            }
        }
        .onChange(of: environment.session?.summary?.endReason) { _, reason in
            if reason != nil { environment.refreshWidgetSummary() }
        }
        .onOpenURL { url in
            if LaunchRequests.isDailyURL(url) {
                launchRequests.requestDaily()
                consumeRequests()
            }
        }
        .onAppear {
            refreshDailyStatus()
            consumeRequests()
        }
        .onChange(of: launchRequests.dailyRequested) { _, _ in consumeRequests() }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            refreshDailyStatus()
        }
    }

    /// Recomputed on appear, after a run and at midnight; the store itself is not observable.
    private func refreshDailyStatus() {
        let streak = environment.history.dailyStreak()
        let played = environment.history.hasCompletedDaily(dayKey: DailySeed.dayKey(for: .now))
        let streakText = streak == 1 ? String(localized: "1 day streak") : String(localized: "\(streak) day streak")
        dailyStatus = played ? String(localized: "Done today · \(streakText)") : streakText
    }

    private func startRun(daily: Bool, packID: String? = nil) {
        environment.applySettings()
        if let packID {
            self.packID = packID
        }
        environment.startRun(daily: daily, packID: packID)
        isRunPresented = true
    }

    /// Runs once the cover has finished animating out, so Results stays on screen until then.
    private func runDidDismiss() {
        environment.session = nil
        environment.refreshWidgetSummary()
        refreshDailyStatus()
        consumeRequests()
    }

    /// Starts the daily if the widget or an intent asked for it. A run that is still being played
    /// (intro, play or paused) wins; a finished run on its results screen is replaced.
    private func consumeRequests() {
        guard launchRequests.dailyRequested else { return }
        if let session = environment.session, isRunPresented {
            if session.screen == .results {
                isRunPresented = false   // runDidDismiss consumes the request after the animation
            } else {
                _ = launchRequests.takeDailyRequest()
            }
            return
        }
        if launchRequests.takeDailyRequest() {
            startRun(daily: true)
        }
    }
}

#Preview {
    HomeView()
        .environment(AppEnvironment.preview())
}
