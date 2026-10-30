import Combine
import SwiftUI

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published private(set) var events: [ScheduleEvent] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    func load(using dependencies: AppDependencies) async {
        if events.isEmpty { isLoading = true }
        errorMessage = nil
        defer { isLoading = false }
        do {
            let loans = try await dependencies.borrowingRepository.fetchMyLoans()
            try await dependencies.accountRepository.syncScheduleEvents(for: loans)
        } catch {
            errorMessage = error.localizedDescription
        }
        do {
            events = try await dependencies.accountRepository.loadScheduleEvents()
        } catch {
            if errorMessage == nil {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct CalendarView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var router: AppRouter
    @StateObject private var model = CalendarViewModel()
    @State private var displayedMonth = Date()
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var isOpening = false

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Calendar")
                            .font(AppTheme.rounded(25, weight: .heavy))
                            .foregroundStyle(AppTheme.blue)
                        Text("Pickups and returns")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.green)
                    }
                    monthCard
                    daySection
                    if selectedEvents.isEmpty && !model.events.isEmpty {
                        upcomingSection
                    }
                    if let errorMessage = model.errorMessage {
                        DismissingErrorText(message: errorMessage, size: 12.5)
                    }
                    if model.isLoading || isOpening {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 18)
            }
            .refreshable { await model.load(using: dependencies) }
            BorrowingTabBar(
                selectedTab: 2,
                onHome: { router.go(to: .home) },
                onSearch: { router.go(to: .nearbyMap) },
                onCalendar: {},
                onProfile: { router.go(to: .profile) }
            )
        }
        .background(AppTheme.background)
        .ignoresSafeArea(.container, edges: .bottom)
        .task { await model.load(using: dependencies) }
    }

    private var monthCard: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    shiftMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.blue)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Previous month")
                Spacer()
                Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(AppTheme.rounded(16, weight: .heavy))
                    .foregroundStyle(AppTheme.blue)
                Spacer()
                Button {
                    shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.blue)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next month")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 8) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.green)
                        .frame(maxWidth: .infinity)
                }
                ForEach(Array(monthCells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.surface)
        .overlay {
            RoundedRectangle(cornerRadius: 18).stroke(AppTheme.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func dayCell(_ day: Date) -> some View {
        let selected = calendar.isDate(day, inSameDayAs: selectedDay)
        let today = calendar.isDateInToday(day)
        let marks = events(on: day)
        return Button {
            selectedDay = calendar.startOfDay(for: day)
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 14, weight: selected ? .bold : .semibold))
                    .foregroundStyle(selected ? AppTheme.onBlue : AppTheme.blue)
                    .frame(width: 30, height: 30)
                    .background(selected ? AppTheme.blue : Color.clear)
                    .clipShape(Circle())
                    .overlay {
                        if today && !selected {
                            Circle().stroke(AppTheme.blue, lineWidth: 1.5)
                        }
                    }
                HStack(spacing: 3) {
                    if marks.contains(where: { $0.kind == .pickup }) {
                        Circle().fill(AppTheme.blue).frame(width: 5, height: 5)
                    }
                    if marks.contains(where: { $0.kind == .return }) {
                        Circle().fill(AppTheme.green).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var daySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedDay.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(AppTheme.rounded(16, weight: .heavy))
                .foregroundStyle(AppTheme.blue)
            if selectedEvents.isEmpty && !model.isLoading {
                if model.events.isEmpty {
                    ThemeClipart(name: "ClipartCalendar", height: 150, label: "A calendar and a neighbor with a ladder")
                }
                Text(model.events.isEmpty ? "No pickups or returns yet. They appear here when you borrow or lend a tool." : "Nothing scheduled this day.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(AppTheme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border, lineWidth: 1)
                    }
            } else {
                ForEach(selectedEvents) { event in
                    eventRow(event)
                }
            }
        }
    }

    private var upcomingSection: some View {
        let upcoming = model.events.filter(\.isUpcoming).sorted { $0.occursAt < $1.occursAt }
        return VStack(alignment: .leading, spacing: 10) {
            Text("Coming up")
                .font(AppTheme.rounded(16, weight: .heavy))
                .foregroundStyle(AppTheme.blue)
            if upcoming.isEmpty && !model.isLoading {
                Text("No upcoming pickups or returns.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.green)
            } else {
                ForEach(upcoming.prefix(6)) { event in
                    eventRow(event)
                }
            }
        }
    }

    private func eventRow(_ event: ScheduleEvent) -> some View {
        Button {
            Task { await open(event) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: event.kind == .pickup ? "arrow.down.circle.fill" : "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(event.kind == .pickup ? AppTheme.blue : AppTheme.green)
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.blue)
                    Text(event.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                    Text(event.occursAt.borrowingDateTime)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(AppTheme.green)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.border)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(isOpening || event.reservationID.isEmpty)
        .accessibilityLabel("\(event.title), \(event.occursAt.borrowingDateTime)")
    }

    private var selectedEvents: [ScheduleEvent] {
        events(on: selectedDay).sorted { $0.occursAt < $1.occursAt }
    }

    private func events(on day: Date) -> [ScheduleEvent] {
        model.events.filter { calendar.isDate($0.occursAt, inSameDayAs: day) }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    private var monthCells: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth),
              let dayCount = calendar.range(of: .day, in: .month, for: displayedMonth)?.count else {
            return []
        }
        let weekday = calendar.component(.weekday, from: interval.start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            cells.append(calendar.date(byAdding: .day, value: offset, to: interval.start))
        }
        return cells
    }

    private func shiftMonth(by value: Int) {
        guard let next = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = next
        if !calendar.isDate(selectedDay, equalTo: next, toGranularity: .month) {
            selectedDay = calendar.dateInterval(of: .month, for: next)?.start ?? next
        }
    }

    private func open(_ event: ScheduleEvent) async {
        guard !event.reservationID.isEmpty else { return }
        isOpening = true
        defer { isOpening = false }
        do {
            let loan = try await dependencies.borrowingRepository.fetchReservation(id: event.reservationID)
            dependencies.open(loan, router: router)
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }
}
