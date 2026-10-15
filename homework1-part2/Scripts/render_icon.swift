// Renders the app icon from the same SwiftUI logo the app uses (PlatePlan/Design/CookdMark.swift).
//
// Run:  swiftc -parse-as-library PlatePlan/Design/CookdMark.swift Scripts/render_icon.swift -o /tmp/render_icon \
//         && /tmp/render_icon PlatePlan/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import AppKit
import SwiftUI

@main
struct RenderIcon {
    @MainActor
    static func main() {
        let output = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"
        let renderer = ImageRenderer(content: CookdMark(tileCornerRadius: 0).frame(width: 1024, height: 1024))
        renderer.scale = 1
        guard let image = renderer.cgImage else { fatalError("Couldn't render the icon") }
        // App Store icons must be opaque: draw onto a solid RGB canvas with no alpha channel.
        let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
        let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
        try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
        print("Wrote \(output)")
    }
}
