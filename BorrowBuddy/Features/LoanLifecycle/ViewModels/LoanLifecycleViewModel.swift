import AVFoundation
import Combine
import Photos
import UIKit

@MainActor
final class LoanLifecycleViewModel: ObservableObject {
    @Published private(set) var stage: LoanLifecycleStage = .pending
    @Published private(set) var pickupPhotos: [EvidencePhoto] = []
    @Published private(set) var returnPhotos: [EvidencePhoto] = []
    @Published private(set) var comparisonResults: [ConditionComparisonResult] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var kitConfirmed = false
    @Published var wearReviewed = false
    @Published var conditionNote = "No existing wear noted"

    private let photoStore = EvidencePhotoStore()
    private(set) var reservationID = "preview-reservation"

    func configure(reservationID: String, stage: LoanLifecycleStage = .pending) {
        if self.reservationID != reservationID {
            comparisonResults = []
            errorMessage = nil
            conditionNote = "No existing wear noted"
            kitConfirmed = false
            wearReviewed = false
        }
        self.reservationID = reservationID
        self.stage = stage
        pickupPhotos = photoStore.load(reservationID: reservationID, phase: .pickup)
        returnPhotos = photoStore.load(reservationID: reservationID, phase: .return)
    }

    func restore(using repository: LoanLifecycleRepository) async {
        do {
            if let note = try await repository.restoreEvidence(reservationID: reservationID) { conditionNote = note }
            pickupPhotos = photoStore.load(reservationID: reservationID, phase: .pickup)
            returnPhotos = photoStore.load(reservationID: reservationID, phase: .return)
        } catch { errorMessage = error.localizedDescription }
    }

    func photos(for phase: EvidencePhase) -> [EvidencePhoto] {
        phase == .pickup ? pickupPhotos : returnPhotos
    }

    func image(for photo: EvidencePhoto) -> UIImage? {
        photoStore.image(for: photo, reservationID: reservationID)
    }

    func capture(_ image: UIImage, phase: EvidencePhase) {
        let photos = photos(for: phase)
        guard photos.count < EvidenceAngle.allCases.count else { return }
        let angle = EvidenceAngle.allCases[photos.count]
        do {
            let photo = try photoStore.save(
                image,
                reservationID: reservationID,
                phase: phase,
                angle: angle
            )
            if phase == .pickup {
                pickupPhotos.removeAll { $0.angle == angle }
                pickupPhotos.append(photo)
                comparisonResults = []
            } else {
                returnPhotos.removeAll { $0.angle == angle }
                returnPhotos.append(photo)
                comparisonResults = []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func retakeLast(phase: EvidencePhase) {
        let photo = photos(for: phase).last
        if let photo { try? photoStore.remove(photo, reservationID: reservationID) }
        comparisonResults = []
        if phase == .pickup {
            _ = pickupPhotos.popLast()
        } else {
            _ = returnPhotos.popLast()
        }
    }

    func requestCameraAccess() async {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined else { return }
        _ = await AVCaptureDevice.requestAccess(for: .video)
    }

    func move(
        to newStage: LoanLifecycleStage,
        using repository: LoanLifecycleRepository
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            guard LoanLifecyclePolicy.canTransition(from: stage, to: newStage) else {
                throw LoanLifecycleViewModelError.invalidTransition
            }
            try await repository.setStage(reservationID: reservationID, stage: newStage)
            stage = newStage
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func analyzeCondition(using service: ConditionComparisonService) async -> Bool {
        guard !isLoading else { return false }
        guard pickupPhotos.count == EvidenceAngle.allCases.count,
              returnPhotos.count == EvidenceAngle.allCases.count else {
            errorMessage = LoanLifecycleViewModelError.missingPhotoPairs.localizedDescription
            return false
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            var results: [ConditionComparisonResult] = []
            for angle in EvidenceAngle.allCases {
                guard let before = pickupPhotos.first(where: { $0.angle == angle }),
                      let after = returnPhotos.first(where: { $0.angle == angle }) else {
                    throw LoanLifecycleViewModelError.missingPhotoPairs
                }
                let distance = try await service.compare(
                    baselineData: photoStore.data(for: before, reservationID: reservationID),
                    returnData: photoStore.data(for: after, reservationID: reservationID)
                )
                results.append(ConditionComparisonResult(
                    angle: angle,
                    distance: distance,
                    verdict: ConditionComparisonPolicy.verdict(for: distance)
                ))
            }
            comparisonResults = results
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func syncConditionAnalysis(using repository: LoanLifecycleRepository) async -> Bool {
        guard comparisonResults.count == EvidenceAngle.allCases.count else {
            errorMessage = LoanLifecycleViewModelError.analysisIncomplete.localizedDescription
            return false
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await repository.saveConditionAnalysis(
                reservationID: reservationID,
                results: comparisonResults
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func syncEvidence(
        phase: EvidencePhase,
        using repository: LoanLifecycleRepository
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await repository.saveEvidence(
                reservationID: reservationID,
                phase: phase,
                photos: photos(for: phase),
                conditionNote: conditionNote
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func complete(
        settlement: LoanSettlement,
        using repository: LoanLifecycleRepository
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            guard LoanLifecyclePolicy.canTransition(from: stage, to: .completed) else {
                throw LoanLifecycleViewModelError.invalidTransition
            }
            try await repository.completeLoan(
                reservationID: reservationID,
                settlement: settlement
            )
            stage = .completed
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

enum LoanLifecycleViewModelError: LocalizedError {
    case invalidTransition
    case missingPhotoPairs
    case analysisIncomplete

    var errorDescription: String? {
        switch self {
        case .invalidTransition:
            "This loan step cannot be completed yet. Finish the previous step first."
        case .missingPhotoPairs:
            "Capture all 8 pickup and return photo pairs before comparison."
        case .analysisIncomplete:
            "Vision comparison has not finished. Please wait and try again."
        }
    }
}
