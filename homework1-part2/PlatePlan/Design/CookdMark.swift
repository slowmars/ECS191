import SwiftUI

/// The Cookd logo: a sunny-side-up egg in a pan on a green tile.
/// Drawn in code so it stays sharp at any size; the app icon is rendered from this same view
/// (Scripts/render_icon.swift).
struct CookdMark: View {
    /// false draws just the pan and egg (for use on a green background you already have).
    var showsTile = true
    /// The app icon is a full square (iOS rounds the corners itself).
    var tileCornerRadius: CGFloat = 22.4

    static let green = Color(red: 0.180, green: 0.580, blue: 0.340)
    static let deepGreen = Color(red: 0.110, green: 0.430, blue: 0.250)
    static let yolk = Color(red: 1.0, green: 0.760, blue: 0.180)

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height) / 100
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }

            if showsTile {
                let tile = Path(roundedRect: CGRect(origin: .zero, size: CGSize(width: 100 * s, height: 100 * s)),
                                cornerRadius: tileCornerRadius * s, style: .continuous)
                context.fill(tile, with: .linearGradient(Gradient(colors: [Self.green, Self.deepGreen]),
                                                         startPoint: p(0, 0), endPoint: p(100, 100)))
            }

            // Center the pan and handle on the tile, with breathing room for the icon mask.
            context.translateBy(x: 50 * s, y: 50 * s)
            context.scaleBy(x: 0.88, y: 0.88)
            context.translateBy(x: -48 * s, y: -52.5 * s)

            // Pan handle, pointing to the top right.
            var handle = Path(roundedRect: CGRect(x: -5 * s, y: -4.5 * s, width: 34 * s, height: 9 * s),
                              cornerRadius: 4.5 * s)
            handle = handle.applying(CGAffineTransform(rotationAngle: -.pi / 4)
                .concatenating(CGAffineTransform(translationX: 62 * s, y: 40 * s)))
            context.fill(handle, with: .color(.white))

            // Pan: white rim, dark green inside.
            let center = p(43, 57)
            context.fill(Path(ellipseIn: CGRect(x: center.x - 31 * s, y: center.y - 31 * s, width: 62 * s, height: 62 * s)),
                         with: .color(.white))
            context.fill(Path(ellipseIn: CGRect(x: center.x - 25 * s, y: center.y - 25 * s, width: 50 * s, height: 50 * s)),
                         with: .color(Self.deepGreen))

            // Egg white: a soft, uneven blob.
            var white = Path()
            white.move(to: p(43, 38))
            white.addCurve(to: p(62, 54), control1: p(55, 37), control2: p(63, 44))
            white.addCurve(to: p(46, 74), control1: p(61, 64), control2: p(55, 74))
            white.addCurve(to: p(25, 60), control1: p(36, 74), control2: p(25, 70))
            white.addCurve(to: p(43, 38), control1: p(25, 48), control2: p(32, 39))
            white.closeSubpath()
            context.fill(white, with: .color(.white))

            // Yolk with a little wink: the "d" in Cookd is for done, and happy about it.
            let yolkCenter = p(44, 56)
            context.fill(Path(ellipseIn: CGRect(x: yolkCenter.x - 10.5 * s, y: yolkCenter.y - 10.5 * s,
                                                width: 21 * s, height: 21 * s)),
                         with: .color(Self.yolk))
            let face = GraphicsContext.Shading.color(Self.deepGreen)
            context.fill(Path(ellipseIn: CGRect(x: 39 * s, y: 51.5 * s, width: 3 * s, height: 3.4 * s)), with: face)
            var wink = Path()
            wink.move(to: p(45.5, 53.4))
            wink.addLine(to: p(49, 53.4))
            context.stroke(wink, with: face, style: StrokeStyle(lineWidth: 1.6 * s, lineCap: .round))
            var smile = Path()
            smile.move(to: p(40, 58.5))
            smile.addQuadCurve(to: p(48, 58.5), control: p(44, 62.5))
            context.stroke(smile, with: face, style: StrokeStyle(lineWidth: 1.6 * s, lineCap: .round))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The logo next to the name, for the top of the Recipes tab and the sign-in screen.
struct CookdWordmark: View {
    var size: CGFloat = 28

    var body: some View {
        HStack(spacing: size * 0.28) {
            CookdMark()
                .frame(width: size * 1.15, height: size * 1.15)
                .shadow(color: CookdMark.green.opacity(0.25), radius: size * 0.2, y: size * 0.08)
            Text("Cookd")
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .tracking(-size * 0.02)
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cookd")
        .accessibilityAddTraits(.isHeader)
    }
}
