import SwiftUI

struct ReservationPendingView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var flow: BorrowingFlowStore
    @EnvironmentObject private var lifecycle: LoanLifecycleViewModel
    @StateObject private var model = CommunityViewModel()
    @StateObject private var reminder = ReservationPendingViewModel()
    @State private var confirmCancel = false
    private var loan: ReservationRecord? { flow.reservation }
    private var isOwner: Bool { loan?.ownerID == dependencies.authenticationService.currentUserID }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    LoanHeader(title: "Reservation pending", subtitle: loan?.ownerAccepted == true ? "Pickup confirmed by the owner" : "Waiting for the owner's confirmation") { router.go(to: .home) }
                    if let loan {
                        VStack(spacing: 10) {
                            Image(systemName: loan.isOpen ? "clock" : "arrow.uturn.backward").font(.system(size: 36, weight: .light)).foregroundStyle(AppTheme.blue)
                                .frame(width: 64, height: 64).background(AppTheme.blue.opacity(0.08)).clipShape(Circle())
                            StatusPill(title: loan.status.rawValue.capitalized, filled: true)
                        }.frame(maxWidth: .infinity)
                        LoanProgressBar(active: 0)
                        LoanCard {
                            VStack(spacing: 11) {
                                BorrowingInfoRow(label: loan.isOpen ? "Pending Hold" : "Hold released", value: "\(loan.totalHold) LC")
                                BorrowingInfoRow(label: "Receipt", value: "#\(loan.receipt)")
                                BorrowingInfoRow(label: "Requested", value: loan.requestedAt.borrowingShortDate)
                                Text(loan.isOpen ? "Held in your LendCredit wallet until the loan is settled. The owner must accept before inspection." : "The full pending hold was returned to the borrower.")
                                    .font(.system(size: 13)).foregroundStyle(AppTheme.secondaryText).frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        LoanCard {
                            VStack(alignment: .leading, spacing: 11) {
                                HStack {
                                    Text("Return reminder").font(AppTheme.rounded(15, weight: .heavy)).foregroundStyle(AppTheme.blue)
                                    Spacer()
                                    Text(reminder.eventMessage).font(.system(size: 11)).foregroundStyle(AppTheme.green)
                                }
                                BorrowingInfoRow(label: "Event", value: "Return \(loan.toolName)", icon: "calendar")
                                BorrowingInfoRow(label: "When", value: loan.returnAt.borrowingDateTime, icon: "clock")
                                BorrowingInfoRow(label: "Alerts", value: "24 hr + 2 hr before", icon: "bell")
                                Button("Add event") { Task { await reminder.addEvent(loan, using: dependencies.eventReminderService) } }
                                    .font(AppTheme.rounded(14, weight: .bold)).foregroundStyle(.white).padding(.horizontal, 24).padding(.vertical, 12)
                                    .background(AppTheme.blue).clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        PickupMapCard(coordinate: loan.toolSnapshot.coordinate, label: "Pickup · \(loan.pickupAddress)").frame(height: 165)
                        if loan.lifecycleStage == .pickupInspection {
                            LoanNotice(icon: "camera", title: "Shared baseline", message: "The borrower records eight angles. Each person acknowledges the same evidence using their own account.")
                        }
                        HStack {
                            Button("Message neighbor") { router.go(to: .loanChat) }
                            Spacer()
                            if loan.status == .pending { Button("Cancel", role: .destructive) { confirmCancel = true } }
                        }.font(.system(size: 12, weight: .semibold)).foregroundStyle(AppTheme.blue).disabled(model.isLoading)
                    }
                    AccountSaveStatus(error: model.error ?? reminder.errorMessage, success: nil)
                }.padding(.horizontal, 18).padding(.vertical, 8)
            }
            if let loan, loan.status == .active {
                PrimaryButton(title: "Continue active loan", systemImage: "arrow.right") {
                    router.go(to: .pickupConfirmed)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.white)
            } else if let loan, loan.status == .pending {
                VStack(spacing: 10) {
                    if isOwner && !loan.ownerAccepted {
                        PrimaryButton(title: model.isLoading ? "Accepting..." : "Accept request", enabled: !model.isLoading) {
                            Task {
                                _ = await model.perform {
                                    try await dependencies.communityRepository.respond(reservationID: loan.id, accepted: true)
                                    try await dependencies.refreshSelectedLoan()
                                }
                            }
                        }
                        LoanOutlineButton(title: "Decline & release hold", enabled: !model.isLoading) { confirmCancel = true }
                    } else if loan.acknowledgements.contains(loan.borrowerID) && loan.acknowledgements.contains(loan.ownerID) {
                        PrimaryButton(title: "Continue to active loan", systemImage: "arrow.right") {
                            router.go(to: .pickupConfirmed)
                        }
                    } else if loan.acknowledgements.contains(dependencies.authenticationService.currentUserID ?? "") {
                        PrimaryButton(title: "Waiting for acknowledgement", enabled: false) {}
                    } else if isOwner {
                        PrimaryButton(title: lifecycle.pickupPhotos.count == 8 ? "Review baseline" : "Waiting for baseline photos", enabled: lifecycle.pickupPhotos.count == 8) { router.go(to: .baselineReview) }
                    } else {
                        PrimaryButton(title: loan.ownerAccepted ? "Meet for pickup" : "Waiting for owner", systemImage: "person.2", enabled: loan.ownerAccepted) { router.go(to: .pickupMeet) }
                    }
                }.padding(.horizontal, 18).padding(.vertical, 12).background(Color.white)
            }
        }.background(AppTheme.background)
            .alert("Cancel this pending reservation?", isPresented: $confirmCancel) {
                Button("Keep reservation", role: .cancel) {}
                Button("Release hold", role: .destructive) {
                    guard let loan else { return }
                    Task { _ = await model.perform { try await dependencies.communityRepository.cancel(reservationID: loan.id) } }
                }
            } message: { Text("The full pending hold is refunded. Active loans cannot be cancelled here.") }
            .onChange(of: loan?.status) { old, status in if old == .pending && status == .active { router.go(to: .pickupConfirmed) } }
    }
}
