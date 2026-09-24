import Foundation

/// UserDefaults keys for player settings. Views bind with `@AppStorage(AppSettings.x)`.
enum AppSettings {
    static let soundsEnabled = "settings.soundsEnabled"
    static let hapticsEnabled = "settings.hapticsEnabled"
    static let tapToSort = "settings.tapToSort"
    static let colourHints = "settings.colourHints"
    /// Id of the pack free play uses. The daily challenge always uses the built-in pack.
    static let packID = "settings.packID"

    static func register(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            soundsEnabled: true,
            hapticsEnabled: true,
            tapToSort: false,
            colourHints: false,
        ])
    }
}
