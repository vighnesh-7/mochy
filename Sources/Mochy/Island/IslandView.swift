import SwiftUI

struct IslandRoot: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dropTargeted = false

    var body: some View {
        let size = model.islandBodySize
        let radii = model.cornerRadii
        let shape = NotchShape(topRadius: radii.top, bottomRadius: radii.bottom)

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                if model.welcoming {
                    WelcomeIsland().transition(.opacity)
                } else if model.isExpanded {
                    ExpandedIsland().transition(glide)
                } else {
                    CollapsedIsland().transition(.opacity.animation(.easeOut(duration: 0.12)))
                }
            }
            .frame(width: size.width, height: size.height, alignment: .top)
            .padding(.horizontal, radii.top)
            .background {
                if model.welcoming {
                    shape.fill(Color.black)
                } else if model.prefs.glassSurface {
                    VisualEffect(material: model.prefs.translucency.material)
                        .mask(shape)
                    shape.fill(model.prefs.translucency.fill.opacity(0.55))
                } else {
                    shape.fill(model.prefs.translucency == .carbon ? Island.surface : model.prefs.translucency.fill)
                }
            }
            .clipShape(shape)
            .contentShape(shape)
            .shadow(color: .black.opacity(model.isExpanded ? 0.5 : 0), radius: 20, y: 10)
            .environment(\.clickHaptic, model.prefs.hapticOnClick)
            .onTapGesture {
                guard !model.isExpanded, !model.welcoming else { return }
                if model.prefs.hapticOnClick { hapticClick() }
                model.expand()
            }
            .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
                loadFileURLs(providers) { model.addToShelf($0) }
            }
            .onChange(of: dropTargeted) { _, targeted in
                if targeted, !model.isExpanded, model.prefs.openShelfOnFileDrag { model.expand(tab: .shelf) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Mochy")

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
        .animation(Island.spring(reduceMotion), value: model.isExpanded)
        .animation(Island.spring(reduceMotion), value: model.welcoming)
        .animation(Island.spring(reduceMotion), value: model.activity)
        .animation(Island.spring(reduceMotion), value: model.alert)
        .animation(Island.spring(reduceMotion), value: model.prefs.panelSize)
    }

    /// Content fades up out of the notch while the shape springs open.
    private var glide: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .modifier(active: Glide(progress: 0), identity: Glide(progress: 1)).animation(Island.spring(false).delay(0.04)),
            removal: .modifier(active: Glide(progress: 0), identity: Glide(progress: 1)).animation(.easeIn(duration: 0.12))
        )
    }
}

private struct Glide: ViewModifier {
    let progress: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .blur(radius: (1 - progress) * 8)
            .scaleEffect(0.94 + 0.06 * progress, anchor: .top)
            .offset(y: (1 - progress) * -10)
    }
}
