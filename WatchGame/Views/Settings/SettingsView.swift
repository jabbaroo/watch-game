import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage(AppSettings.soundsEnabled) private var soundsEnabled = true
    @AppStorage(AppSettings.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(AppSettings.tapToSort) private var tapToSort = false
    @AppStorage(AppSettings.colourHints) private var colourHints = false
    @State private var confirmingReset = false

    var body: some View {
        List {
            Section("Feedback") {
                Toggle("Sounds", isOn: $soundsEnabled)
                Toggle("Haptics", isOn: $hapticsEnabled)
            }
            Section {
                Toggle("Tap to sort", isOn: $tapToSort)
                Toggle("Colour hints", isOn: $colourHints)
            } header: {
                Text("Accessibility")
            } footer: {
                Text("Tap to sort lets you tap an edge label instead of swiping. Colour hints add a letter to each colour.")
            }
            Section {
                Button("Reset history", role: .destructive) {
                    confirmingReset = true
                }
            }
            Section("About") {
                LabeledContent("Version", value: Self.versionText)
                if environment.history.isFallback {
                    Text("History is unavailable on this watch right now. Scores are kept for this session only.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .onChange(of: soundsEnabled) { _, _ in environment.applySettings() }
        .onChange(of: hapticsEnabled) { _, _ in environment.applySettings() }
        .confirmationDialog("Reset all history?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                environment.history.reset()
                environment.refreshWidgetSummary()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every run, best score and daily streak will be deleted. This cannot be undone.")
        }
    }

    static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AppEnvironment.preview())
    }
}
