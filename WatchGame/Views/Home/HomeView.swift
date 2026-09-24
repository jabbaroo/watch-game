import SwiftUI
import SwipeSortEngine

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text("Swipe Sort")
                    .font(.headline)
                Text("\(ContentPack.shapesAndColours.items.count) items ready")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    HomeView()
}
