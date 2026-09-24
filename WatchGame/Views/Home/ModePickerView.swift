import SwiftUI
import SwipeSortEngine

/// Picks the pack free play uses. Only reachable when more than one pack is installed.
struct ModePickerView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage(AppSettings.packID) private var packID = ContentPack.shapesAndColours.id

    var body: some View {
        List(environment.packs) { pack in
            Button {
                packID = pack.id
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
                    if pack.id == packID {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .accessibilityAddTraits(pack.id == packID ? .isSelected : [])
        }
        .navigationTitle("Mode")
    }
}

#Preview {
    NavigationStack {
        ModePickerView()
            .environment(AppEnvironment.preview())
    }
}
