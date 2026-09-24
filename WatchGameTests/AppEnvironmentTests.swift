import Foundation
import SwiftData
import Testing
import SwipeSortEngine
@testable import WatchGame

@MainActor
@Suite(.serialized) struct AppEnvironmentTests {
    func makeEnvironment() throws -> AppEnvironment {
        let container = try ModelContainer(for: HistoryStore.schema, configurations: ModelConfiguration(schema: HistoryStore.schema, isStoredInMemoryOnly: true))
        return AppEnvironment(history: HistoryStore(container: container, isFallback: true),
                              haptics: WatchHaptics(isEnabled: false), sound: EngineSound(isEnabled: false),
                              packs: PackLoader.loadPacks())
    }

    @Test func selectedPackFallsBackToTheBuiltInPack() throws {
        let environment = try makeEnvironment()
        defer { UserDefaults.standard.removeObject(forKey: AppSettings.packID) }
        UserDefaults.standard.set("no-such-pack", forKey: AppSettings.packID)
        #expect(environment.selectedPack.id == ContentPack.shapesAndColours.id)
        UserDefaults.standard.set("stroop", forKey: AppSettings.packID)
        #expect(environment.selectedPack.id == "stroop")
    }

    @Test func freePlayUsesTheSelectedPackAndTheDailyUsesTheBuiltInPack() throws {
        let environment = try makeEnvironment()
        defer { UserDefaults.standard.removeObject(forKey: AppSettings.packID) }
        UserDefaults.standard.set("stroop", forKey: AppSettings.packID)
        #expect(environment.startRun(daily: false).pack.id == "stroop")
        #expect(environment.startRun(daily: true).pack.id == ContentPack.shapesAndColours.id)
        #expect(environment.startRun(daily: false, packID: ContentPack.shapesAndColours.id).pack.id == ContentPack.shapesAndColours.id)
    }
}
