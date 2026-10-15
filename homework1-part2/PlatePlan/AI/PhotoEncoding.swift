import UIKit

enum PhotoEncoding {
    /// Shrinks a photo so its longest side is at most `maxSide` pixels and returns base64 JPEG.
    /// Claude doesn't gain accuracy from larger images, and smaller uploads are faster.
    static func jpegBase64(from image: UIImage, maxSide: CGFloat = 1568) -> String? {
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, maxSide / longest)
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8)?.base64EncodedString()
    }
}
