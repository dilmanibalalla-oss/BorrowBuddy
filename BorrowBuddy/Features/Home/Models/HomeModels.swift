import SwiftUI

struct RentalSummary {
    let toolName: String
    let dueDate: String
    let ownerName: String
    let progress: Double
}

struct FeaturedTool: Identifiable {
    let id = UUID()
    let name: String
    let distance: String
    let creditCost: Int
}

struct ActivityItem: Identifiable {
    let id = UUID()
    let text: String
    let creditChange: Int

    var color: Color {
        creditChange >= 0 ? AppTheme.green : AppTheme.coral
    }
}
