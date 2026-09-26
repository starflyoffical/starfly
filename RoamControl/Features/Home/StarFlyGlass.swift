import SwiftUI

struct StarFlyGlass: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let shape: AnyShape

    func body(content: Content) -> some View {
        content
            .glassEffect(reduceMotion ? .regular : .regular.interactive(), in: shape)
            .overlay {
                shape
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.14), location: 0),
                                .init(color: .white.opacity(0.045), location: 0.18),
                                .init(color: .clear, location: 0.48),
                                .init(color: .white.opacity(0.025), location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .allowsHitTesting(false)
            }
            .overlay {
                shape
                    .stroke(
                        .white.opacity(0.22),
                        lineWidth: 0.75
                    )
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.09), radius: 8, y: 4)
    }
}

extension View {
    func starFlyGlass<S: Shape>(in shape: S) -> some View {
        modifier(StarFlyGlass(shape: AnyShape(shape)))
    }
}

struct StarFlyPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.88),
                value: configuration.isPressed
            )
    }
}
