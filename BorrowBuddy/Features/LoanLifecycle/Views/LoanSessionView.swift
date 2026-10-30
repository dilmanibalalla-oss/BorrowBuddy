import SwiftUI

// Keep the original separate screens while sharing one live loan subscription.
struct LoanSessionView<Content: View>: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var flow: BorrowingFlowStore
    @EnvironmentObject private var lifecycle: LoanLifecycleViewModel
    @EnvironmentObject private var router: AppRouter
    @State private var loadError: String?
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        Group {
            if flow.reservation != nil {
                content
            } else {
                VStack(spacing: 18) {
                    ContentUnavailableView("Select a reservation", systemImage: "tray",
                        description: Text("Pickup needs a saved reservation. Open your loan from Home instead of continuing with placeholder details."))
                    PrimaryButton(title: "Open my reservations") { router.go(to: .loanList) }
                        .padding(.horizontal, 18)
                }.background(AppTheme.background)
            }
        }
            .task(id: flow.reservation?.id) {
                guard let id = flow.reservation?.id else { return }
                lifecycle.configure(reservationID: id, stage: flow.reservation?.lifecycleStage ?? .pending)
                await lifecycle.restore(using: dependencies.loanLifecycleRepository)
                do {
                    for try await loan in dependencies.borrowingRepository.reservationUpdates(id: id) {
                        guard !Task.isCancelled, flow.reservation?.id == id else { return }
                        let previous = flow.reservation
                        dependencies.apply(loan)
                        if previous?.lifecycleStage != loan.lifecycleStage || previous?.acknowledgements != loan.acknowledgements {
                            await lifecycle.restore(using: dependencies.loanLifecycleRepository)
                        }
                        if dependencies.authenticationService.currentUserID == loan.borrowerID,
                           NonReturnPolicy.shouldBlockBorrowing(loans: [loan], borrowerID: loan.borrowerID, now: Date()) {
                            await dependencies.accountRepository.syncBorrowingBlock(for: [loan])
                        }
                        let preferences = (try? await dependencies.accountRepository.loadNotificationSettings()) ?? .standard
                        await dependencies.notificationService.schedule(for: loan, preferences: preferences)
                        await dependencies.notificationService.watchLoanMessages([loan])
                    }
                } catch is CancellationError {
                    // Leaving a screen cancels its subscription, not its reservation.
                } catch { if !Task.isCancelled { loadError = error.localizedDescription } }
            }
            .alert("Unable to refresh loan", isPresented: Binding(get: { loadError != nil }, set: { if !$0 { loadError = nil } })) {
                Button("OK") { loadError = nil }
            } message: { Text(FriendlyError.clean(loadError ?? "")) }
            .task(id: loadError) {
                guard loadError != nil else { return }
                try? await Task.sleep(for: .seconds(3))
                loadError = nil
            }
    }
}

@MainActor
extension AppDependencies {
    func open(_ loan: ReservationRecord, router: AppRouter) {
        apply(loan)
        let presentation = LoanScreenPresentation.screen(
            for: loan,
            userID: authenticationService.currentUserID,
            baselineCount: loanLifecycle.pickupPhotos.count
        )
        switch presentation {
        case .pending:
            router.go(to: .reservationPending)
        case .pickup:
            router.go(to: .pickupMeet)
        case .baseline:
            router.go(to: .baselineReview)
        case .active:
            router.go(to: .activeLoan)
        case .returning:
            router.go(to: .toolReturn)
        case .returnPhotos:
            router.go(to: .returnCapture)
        case .review:
            router.go(to: .ownerReview)
        case .completed:
            router.go(to: .loanCompleted)
        }
    }

    func apply(_ loan: ReservationRecord) {
        // Do not leave a default tool/coordinate attached to a different loan.
        if borrowingFlow.selectedTool.id != loan.toolID {
            borrowingFlow.selectedTool = loan.toolSnapshot
        }
        borrowingFlow.reservation = loan
        borrowingFlow.quote = loan.quote
        loanLifecycle.configure(reservationID: loan.id, stage: loan.lifecycleStage)
    }

    func refreshSelectedLoan() async throws {
        guard let id = borrowingFlow.reservation?.id else {
            throw CommunityError.invalidInput("Select a saved reservation first.")
        }
        let loan = try await borrowingRepository.fetchReservation(id: id)
        guard !Task.isCancelled, borrowingFlow.reservation?.id == id else { throw CancellationError() }
        apply(loan)
    }
}
