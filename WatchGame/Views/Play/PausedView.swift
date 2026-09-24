import SwiftUI

struct PausedView: View {
    let session: GameSession
    var onQuit: () -> Void
    @State private var confirmingQuit = false

    var body: some View {
        VStack(spacing: 10) {
            Text("Paused")
                .font(.headline)
            Button {
                session.resume()
            } label: {
                Label("Resume", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .handGestureShortcut(.primaryAction)
            .buttonStyle(.borderedProminent)
            Button(role: .destructive) {
                confirmingQuit = true
            } label: {
                Label("Quit run", systemImage: "xmark")
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .confirmationDialog("Quit this run?", isPresented: $confirmingQuit, titleVisibility: .visible) {
            Button("Quit", role: .destructive) {
                session.quit()
                onQuit()
            }
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text("Finished rounds are kept. The run is marked incomplete.")
        }
    }
}
