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
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        guard let observation = request.results?.first as? VNFeaturePrintObservation else {
            throw ConditionComparisonError.featurePrintUnavailable
        }
        return observation
    }
}

final class DemoConditionComparisonService: ConditionComparisonService {
    func compare(baselineData: Data, returnData: Data) async throws -> Float {
        0.18
    }
}
