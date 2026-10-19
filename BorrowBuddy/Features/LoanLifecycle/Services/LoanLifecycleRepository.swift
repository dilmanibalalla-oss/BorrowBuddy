import Foundation

protocol LoanLifecycleRepository {
    func restoreEvidence(reservationID: String) async throws -> String?
    func setStage(reservationID: String, stage: LoanLifecycleStage) async throws
    func saveEvidence(
        reservationID: String,
        phase: EvidencePhase,
        photos: [EvidencePhoto],
        conditionNote: String
    ) async throws
    func saveConditionAnalysis(
        reservationID: String,
        results: [ConditionComparisonResult]
    ) async throws
    func completeLoan(reservationID: String, settlement: LoanSettlement) async throws
}

final class DemoLoanLifecycleRepository: LoanLifecycleRepository {
    func restoreEvidence(reservationID: String) async throws -> String? { nil }
    func setStage(reservationID: String, stage: LoanLifecycleStage) async throws {
        try await Task.sleep(for: .milliseconds(180))
    }

    func saveEvidence(
        reservationID: String,
        phase: EvidencePhase,
        photos: [EvidencePhoto],
        conditionNote: String
    ) async throws {
        try await Task.sleep(for: .milliseconds(180))
    }

    func saveConditionAnalysis(
        reservationID: String,
        results: [ConditionComparisonResult]
    ) async throws {
        try await Task.sleep(for: .milliseconds(120))
    }

    func completeLoan(reservationID: String, settlement: LoanSettlement) async throws {
        try await Task.sleep(for: .milliseconds(180))
    }
}
