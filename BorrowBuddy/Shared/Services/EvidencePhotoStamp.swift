import UIKit

enum EvidencePhotoStamp {
    /// Draws the capture time onto the photo so the saved file carries its own date stamp.
    static func apply(to image: UIImage, at date: Date = Date()) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale == 0 ? 1 : image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(at: .zero)
            let text = date.formatted(date: .abbreviated, time: .standard) as NSString
            let fontSize = max(18, image.size.width * 0.04)
            let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            let padding = fontSize * 0.6
            let rect = CGRect(
                x: padding,
                y: image.size.height - textSize.height - padding * 3,
                width: textSize.width + padding * 2,
                height: textSize.height + padding
            )
            UIColor.black.withAlphaComponent(0.72).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: 8).fill()
            text.draw(
                at: CGPoint(x: rect.minX + padding, y: rect.minY + padding * 0.35),
                withAttributes: attributes
            )
        }
    }
}
