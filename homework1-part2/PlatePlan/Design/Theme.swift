import SwiftUI

/// PlatePlan's design tokens. Every screen pulls spacing, shape and type from here,
/// so the app feels like one product instead of a collection of screens.
enum Theme {
    /// 4-pt spacing scale.
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 20
        static let photo: CGFloat = 16
        static let small: CGFloat = 12
    }

    /// Minimum tap target (Apple HIG / Fitts's law).
    static let minTap: CGFloat = 44

    /// Rounded SF for headings gives the app a warm, friendly voice; body text stays default SF
    /// for maximum legibility.
    static func heading(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

extension View {
    /// The standard raised card: background, rounded corners and a soft shadow.
    func cardStyle(padding: CGFloat = Theme.Space.l) -> some View {
        self
            .padding(padding)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Theme.Radius.card))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}

/// Buttons gently shrink while pressed, so every tap gets instant feedback (Doherty threshold).
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}
