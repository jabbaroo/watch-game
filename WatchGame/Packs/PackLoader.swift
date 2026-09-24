import Foundation
import OSLog
import SwipeSortEngine

/// The packs available to play: the built-in shapes pack first, then every valid
/// `*.pack.json` in the bundle, sorted by file name (a numeric prefix sets the order on Home).
enum PackLoader {
    private static let logger = Logger(subsystem: "com.pynto.sortsprint", category: "packs")

    static func loadPacks(from bundle: Bundle = .main) -> [ContentPack] {
        var packs = [ContentPack.shapesAndColours]
        for url in packURLs(in: bundle) {
            do {
                let pack = try load(url)
                if packs.contains(where: { $0.id == pack.id }) {
                    logger.error("Skipping \(url.lastPathComponent, privacy: .public): duplicate pack id \(pack.id, privacy: .public)")
                    continue
                }
                packs.append(pack)
            } catch {
                logger.error("Skipping \(url.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
        return packs
    }

    /// Decodes and validates every bundled pack, throwing on the first failure.
    /// Tests call this so a broken pack fails the build instead of being skipped.
    static func validateBundledPacks(in bundle: Bundle = .main) throws -> [ContentPack] {
        var packs = [ContentPack.shapesAndColours]
        for url in packURLs(in: bundle) {
            packs.append(try load(url))
        }
        return packs
    }

    private static func packURLs(in bundle: Bundle) -> [URL] {
        (bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasSuffix(".pack.json") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func load(_ url: URL) throws -> ContentPack {
        let pack = try JSONDecoder().decode(ContentPack.self, from: Data(contentsOf: url))
        try pack.validate()
        return pack
    }
}
