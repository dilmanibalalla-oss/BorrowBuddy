import UIKit

enum PhotoEncoding {
    static let maximumBytes = 600_000

    /// Bounded JPEGs keep each private Firestore photo document below its size limit.
    static func jpeg(_ image: UIImage) throws -> Data {
        let size = image.size
        guard size.width > 0, size.height > 0 else { throw ConditionComparisonError.unreadableImage }
        let scale = min(1, 1280 / max(size.width, size.height))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: CGSize(width: size.width * scale, height: size.height * scale), format: format)
            .image { _ in image.draw(in: CGRect(x: 0, y: 0, width: size.width * scale, height: size.height * scale)) }
        for quality in [0.8, 0.65, 0.5, 0.35, 0.2] {
            if let data = resized.jpegData(compressionQuality: quality), data.count <= maximumBytes { return data }
        }
        throw CommunityError.invalidInput("Choose a smaller, clearer image.")
    }
}
