import UIKit

final class EvidencePhotoStore {
    private let fileManager = FileManager.default

    func save(
        _ image: UIImage,
        reservationID: String,
        phase: EvidencePhase,
        angle: EvidenceAngle
    ) throws -> EvidencePhoto {
        let directory = try evidenceDirectory(reservationID: reservationID)
        let fileName = "\(phase.rawValue)-\(angle.rawValue).jpg"
        let url = directory.appendingPathComponent(fileName)
        let data = try PhotoEncoding.jpeg(image)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        let photo = EvidencePhoto(
            id: "\(phase.rawValue)-\(angle.rawValue)",
            phase: phase,
            angle: angle,
            fileName: fileName,
            capturedAt: Date()
        )
        try JSONEncoder().encode(photo).write(to: url.appendingPathExtension("json"), options: .atomic)
        return photo
    }

    func load(reservationID: String, phase: EvidencePhase) -> [EvidencePhoto] {
        guard let directory = try? evidenceDirectory(reservationID: reservationID) else { return [] }
        return EvidenceAngle.allCases.compactMap { angle in
            let url = directory.appendingPathComponent("\(phase.rawValue)-\(angle.rawValue).jpg.json")
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(EvidencePhoto.self, from: data)
        }
    }

    func restore(data: Data, photo: EvidencePhoto, reservationID: String) throws {
        let directory = try evidenceDirectory(reservationID: reservationID)
        let url = directory.appendingPathComponent(photo.fileName)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        try JSONEncoder().encode(photo).write(to: url.appendingPathExtension("json"), options: .atomic)
    }

    func remove(_ photo: EvidencePhoto, reservationID: String) throws {
        let directory = try evidenceDirectory(reservationID: reservationID)
        for url in [directory.appendingPathComponent(photo.fileName), directory.appendingPathComponent(photo.fileName + ".json")] {
            if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
        }
    }

    func image(for photo: EvidencePhoto, reservationID: String) -> UIImage? {
        guard let directory = try? evidenceDirectory(reservationID: reservationID) else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(photo.fileName).path)
    }

    func data(for photo: EvidencePhoto, reservationID: String) throws -> Data {
        let directory = try evidenceDirectory(reservationID: reservationID)
        return try Data(contentsOf: directory.appendingPathComponent(photo.fileName))
    }

    private func evidenceDirectory(reservationID: String) throws -> URL {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = applicationSupport
            .appendingPathComponent("LoanEvidence", isDirectory: true)
            .appendingPathComponent(reservationID, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
