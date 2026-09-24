import SwiftUI
import SwipeSortEngine

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var isRunPresented = false
    @AppStorage(AppSettings.packID) private var packID = ContentPack.shapesAndColours.id
    private let launchRequests = LaunchRequests.shared

    private var todayKey: String { DailySeed.dayKey(for: .now) }

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
            .navigationTitle("Swipe Sort")
        }
        .fullScreenCover(isPresented: $isRunPresented, onDismiss: dismissRun) {
            if let session = environment.session {
                RunView(
                    session: session,
                    onPlayAgain: { startRun(daily: session.isDaily, packID: session.isDaily ? nil : session.pack.id) },
                    onDismiss: dismissRun
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
        .onAppear(perform: consumeRequests)
        .onChange(of: launchRequests.dailyRequested) { _, _ in consumeRequests() }
    }

    private var dailyStatus: String {
        let streak = environment.history.dailyStreak()
        let played = environment.history.hasCompletedDaily(dayKey: todayKey)
        let streakText = streak == 1 ? String(localized: "1 day streak") : String(localized: "\(streak) day streak")
        return played ? String(localized: "Done today · \(streakText)") : streakText
    }

    private func startRun(daily: Bool, packID: String? = nil) {
        environment.applySettings()
        if let packID {
            self.packID = packID
        }
        environment.startRun(daily: daily, packID: packID)
        isRunPresented = true
    }

    private func dismissRun() {
        isRunPresented = false
        environment.session = nil
        environment.refreshWidgetSummary()
    }

    /// Starts the daily if the widget or an intent asked for it and no run is in progress.
    private func consumeRequests() {
        guard launchRequests.dailyRequested else { return }
        if environment.session != nil, isRunPresented {
            _ = launchRequests.takeDailyRequest()
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
