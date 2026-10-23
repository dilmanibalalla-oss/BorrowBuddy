import Foundation
import UIKit
import Vision

protocol ConditionComparisonService {
    func compare(baselineData: Data, returnData: Data) async throws -> Float
}

enum ConditionComparisonError: LocalizedError {
    case unreadableImage
    case featurePrintUnavailable

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            "One of the evidence photos could not be read. Please retake it."
        case .featurePrintUnavailable:
            "Vision could not create an image feature print. Please retake the pair."
        }
    }
}

final class VisionConditionComparisonService: ConditionComparisonService {
    func compare(baselineData: Data, returnData: Data) async throws -> Float {
        try await Task.detached(priority: .userInitiated) {
            guard let baseline = UIImage(data: baselineData)?.cgImage,
                  let returned = UIImage(data: returnData)?.cgImage else {
                throw ConditionComparisonError.unreadableImage
            }

            let before = try Self.featurePrint(for: baseline)
            let after = try Self.featurePrint(for: returned)
            var distance: Float = 0
            try before.computeDistance(&distance, to: after)
            return distance
        }.value
    }

    private static func featurePrint(for image: CGImage) throws -> VNFeaturePrintObservation {
        let prepared = normalized(image)
        let request = VNGenerateImageFeaturePrintRequest()
        #if targetEnvironment(simulator)
        // Revision 2 asks the simulator for an Espresso model it cannot create.
        // Revision 1 still builds a real Vision feature print and supports computeDistance.
        request.revision = VNGenerateImageFeaturePrintRequestRevision1
        request.usesCPUOnly = true
        #endif
        let handler = VNImageRequestHandler(cgImage: prepared, options: [:])
        try handler.perform([request])
        guard let observation = request.results?.first as? VNFeaturePrintObservation else {
            throw ConditionComparisonError.featurePrintUnavailable
        }
        return observation
    }

    /// Vision rejects some JPEG color spaces with an Espresso failure. An 8-bit RGB bitmap is readable on the simulator.
    private static func normalized(_ image: CGImage) -> CGImage {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0,
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else { return image }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }
}

final class DemoConditionComparisonService: ConditionComparisonService {
    func compare(baselineData: Data, returnData: Data) async throws -> Float {
        0.18
    }
}
