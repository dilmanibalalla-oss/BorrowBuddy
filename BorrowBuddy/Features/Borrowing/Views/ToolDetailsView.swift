import _LocationEssentials
import SwiftUI

struct ToolDetailsView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var flow: BorrowingFlowStore
    @EnvironmentObject private var dependencies: AppDependencies

    private var tool: BorrowingTool { flow.selectedTool }
    private var quote: ReservationQuote { flow.quote }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    hero
                    toolSummary
                    ownerCard
                    availabilityCard
                    holdNotice
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 26)
            }

            PrimaryButton(title: tool.ownerID == dependencies.authenticationService.currentUserID ? "Your listing" : "Choose loan dates", enabled: tool.ownerID != dependencies.authenticationService.currentUserID && tool.listingStatus == "available") {
                router.go(to: .reservationReview)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
            .background(Color.white)
        }
        .background(AppTheme.background)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            CompactBackButton {
                router.go(to: .nearbyMap)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(tool.category)
                    .font(AppTheme.rounded(22, weight: .heavy))
                    .foregroundStyle(AppTheme.blue)
                Text(tool.pickupAddress)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.green)
            }
            Spacer()
        }
        .padding(.top, 7)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(red: 0.93, green: 0.93, blue: 0.91), Color(red: 0.38, green: 0.40, blue: 0.38)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            CatalogToolArtwork(tool: tool)
                .frame(height: 175)
                .frame(maxWidth: .infinity)
            if tool.isHighValue {
                Text("High-value · $\(tool.estimatedValue)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(red: 0.62, green: 0.29, blue: 0.02))
                    .padding(.horizontal, 9)
                    .frame(height: 25)
                    .background(Color(red: 1, green: 0.93, blue: 0.80))
                    .padding(12)
            }
        }
        .frame(height: 189)
        .clipped()
        .padding(.top, 7)
    }

    private var toolSummary: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(tool.name)
                    .font(AppTheme.rounded(24, weight: .heavy))
                    .foregroundStyle(AppTheme.blue)
                Spacer()
                Text("\(tool.dailyCredits) LC/day")
                    .font(AppTheme.rounded(17, weight: .heavy))
                    .foregroundStyle(AppTheme.blue)
            }
            Text("\(tool.condition) · \(tool.details)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.green)
        }
        .padding(.top, 13)
    }

    private var ownerCard: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppTheme.yellow.opacity(0.45))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(String(tool.ownerName.prefix(2)).uppercased())
                        .font(AppTheme.rounded(12, weight: .heavy))
                        .foregroundStyle(AppTheme.blue)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(tool.ownerName)
                    .font(AppTheme.rounded(15, weight: .bold))
                    .foregroundStyle(AppTheme.blue)
                Text("Owner · review the condition together at pickup")
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.green)
            }
            Spacer()
            Text("• Owner")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.green)
                .padding(.horizontal, 10)
                .frame(height: 27)
                .background(AppTheme.green.opacity(0.10))
        }
        .padding(12)
        .overlay { Rectangle().stroke(AppTheme.border, lineWidth: 1.5) }
        .padding(.top, 13)
    }

    private var availabilityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pickup & availability")
                .font(AppTheme.rounded(14, weight: .heavy))
                .foregroundStyle(AppTheme.blue)
            BorrowingInfoRow(label: "Pickup", value: tool.pickupAddress, icon: "mappin")
            BorrowingInfoRow(label: "Next available", value: quote.pickupAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()), icon: "calendar")
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { index in
                    dayCell(index)
                }
            }
        }
        .padding(13)
        .overlay { Rectangle().stroke(AppTheme.border, lineWidth: 1.5) }
        .padding(.top, 13)
    }

    private func dayCell(_ index: Int) -> some View {
        let calendar = Calendar.current
        let firstDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        let date = calendar.date(byAdding: .day, value: index, to: firstDay) ?? firstDay
        let pickupDay = calendar.startOfDay(for: quote.pickupAt)
        let returnDay = calendar.startOfDay(for: quote.returnAt)
        let currentDay = calendar.startOfDay(for: date)
        let selected = currentDay >= pickupDay && currentDay <= returnDay

        return Button {
            flow.selectPickupDay(date)
        } label: {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.weekday(.narrow)))
                    .font(.system(size: 10))
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(selected ? AppTheme.blue : AppTheme.green)
            .frame(maxWidth: .infinity)
            .frame(height: 45)
            .background(selected ? AppTheme.yellow : AppTheme.green.opacity(0.09))
            .overlay {
                if selected {
                    Rectangle().stroke(AppTheme.blue, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pickup \(date.formatted(date: .abbreviated, time: .omitted))")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var holdNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "shield.checkered")
                .foregroundStyle(AppTheme.green)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(quote.totalHold) LendCredit hold")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.green)
                Text("Available credits move into a hold when you request. The owner receives rental credits only after approving the return.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.green)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.green.opacity(0.08))
        .padding(.top, 13)
    }
}

