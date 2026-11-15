import SwiftUI

/// The hello card shown once each time Mochy starts from a quit.
/// The word is drawn in Macintosh Skeletal, the filled form of Apple's hello handwriting.
struct WelcomeIsland: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat

    init(shown: Int = 0) {
        _drawn = State(initialValue: shown > 0 ? 1 : 0)
    }

    var body: some View {
        HStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .opacity(drawn > 0.02 ? 1 : 0)
                .scaleEffect(drawn > 0.02 ? 1 : 0.9)
            Text("hello")
                .font(.custom("Macintosh Skeletal Filled", size: 108))
                .foregroundStyle(.white)
                .mask(alignment: .leading) {
                    GeometryReader { geo in
                        let edge = max(0.001, drawn)
                        LinearGradient(
                            stops: [
                                .init(color: .white, location: 0),
                                .init(color: .white, location: max(0, edge - 0.12)),
                                .init(color: .clear, location: edge)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
                .shadow(color: .white.opacity(0.85), radius: 12)
                .shadow(color: .white.opacity(0.4), radius: 22)
                .accessibilityLabel("hello")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: write)
    }

    private func write() {
        guard drawn == 0 else { return }
        if reduceMotion {
            drawn = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeInOut(duration: 0.35)) { model.welcoming = false }
            }
            return
        }
        withAnimation(.easeInOut(duration: 1.7)) { drawn = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.45) {
            withAnimation(.easeInOut(duration: 0.45)) { model.welcoming = false }
        }
    }
}
