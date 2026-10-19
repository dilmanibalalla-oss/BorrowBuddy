import Combine
import Foundation
import CoreLocation

enum NearbyMapEmptyState: Equatable {
    case noListings
    case noSearchMatches
    case outsideRadius
}

@MainActor
final class NearbyMapViewModel: ObservableObject {
    @Published var searchText = ""
    @Published private(set) var tools: [BorrowingTool] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published var radiusKilometers = 5.0
    @Published var showsAllLocations = false
    @Published var origin: CLLocationCoordinate2D?

    private var searchMatches: [BorrowingTool] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return tools.filter {
            query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)
                || $0.category.localizedCaseInsensitiveContains(query)
        }
    }

    var filtersByDistance: Bool { origin != nil && !showsAllLocations }

    var filteredTools: [BorrowingTool] {
        let matches = searchMatches.filter {
            !filtersByDistance || (distance(to: $0).map { $0 <= radiusKilometers * 1000 } ?? true)
        }
        return matches.sorted { (distance(to: $0) ?? 0) < (distance(to: $1) ?? 0) }
    }

    var resultSummary: String {
        if isLoading { return "LOADING AVAILABLE TOOLS…" }
        if errorMessage != nil { return "UNABLE TO REFRESH AVAILABLE TOOLS" }
        if filtersByDistance {
            return "\(filteredTools.count) TOOLS WITHIN \(Int(radiusKilometers)) KM"
        }
        return "\(filteredTools.count) AVAILABLE TOOLS · ALL LOCATIONS"
    }

    var emptyState: NearbyMapEmptyState? {
        guard hasLoaded, !isLoading, errorMessage == nil, filteredTools.isEmpty else { return nil }
        if tools.isEmpty { return .noListings }
        if searchMatches.isEmpty { return .noSearchMatches }
        return .outsideRadius
    }

    func distance(to tool: BorrowingTool) -> Double? {
        guard let origin else { return nil }
        return CLLocation(latitude: origin.latitude, longitude: origin.longitude)
            .distance(from: CLLocation(latitude: tool.latitude, longitude: tool.longitude))
    }

    func load(using repository: BorrowingRepository) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let loadedTools = try await repository.fetchNearbyTools()
            try Task.checkCancellation()
            tools = loadedTools
            hasLoaded = true
        } catch is CancellationError {
            // Leaving the map should not produce a failed-load warning.
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
