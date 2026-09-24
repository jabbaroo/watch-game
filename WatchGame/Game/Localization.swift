import Foundation

/// Helpers for String Catalog keys that come from pack data rather than source code.
enum Localization {
    private static let missingMarker = "\u{0}MISSING\u{0}"

    /// The localised string for a catalog key, or the key itself when the catalog has no entry.
    static func string(_ key: String, bundle: Bundle = .main) -> String {
        let value = bundle.localizedString(forKey: key, value: missingMarker, table: nil)
        return value == missingMarker ? key : value
    }

    static func hasString(_ key: String, bundle: Bundle = .main) -> Bool {
        bundle.localizedString(forKey: key, value: missingMarker, table: nil) != missingMarker
    }
}
