import Combine
import Foundation

final class HomeViewModel: ObservableObject {
    @Published private(set) var creditBalance = 32
    @Published var selectedTab = 0

    let activeRental = RentalSummary(
        toolName: "Ladder",
        dueDate: "due Thursday",
        ownerName: "Alex T.",
        progress: 0.58
    )

    let featuredTool = FeaturedTool(
        name: "Drill",
        distance: "0.2 mi",
        creditCost: 12
    )

    let recentActivity = [
        ActivityItem(text: "Lent: drill to Sam", creditChange: 15),
        ActivityItem(text: "Borrowed: ladder", creditChange: -8)
    ]
}
