import SwiftUI

struct LoanParticipantRow: View {
    let name: String
    var detail = "Owner"
    var badge = "Owner"

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(AppTheme.yellow.opacity(0.45)).frame(width: 42, height: 42)
                .overlay(Text(name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined())
                    .font(AppTheme.rounded(12, weight: .heavy)).foregroundStyle(AppTheme.blue))
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(AppTheme.rounded(16, weight: .bold)).foregroundStyle(AppTheme.blue)
                Text(detail).font(.system(size: 12.5)).foregroundStyle(AppTheme.green)
            }
            Spacer(minLength: 5)
            LoanBadge(title: badge)
        }
    }
}

struct LoanBadge: View {
    let title: String
    var warning = false
    var body: some View {
        Text("• \(title)").font(.system(size: 11, weight: .bold))
            .foregroundStyle(warning ? AppTheme.coral : AppTheme.green)
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(warning ? AppTheme.yellow.opacity(0.13) : AppTheme.green.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct LoanOutlineButton: View {
    let title: String
    var systemImage: String? = nil
    var enabled = true
    let action: () -> Void
    var body: some View {
        if enabled {
            Button(action: action) {
                HStack(spacing: 8) {
                    if let systemImage { Image(systemName: systemImage).accessibilityHidden(true) }
                    Text(title).font(AppTheme.rounded(15, weight: .bold))
                }
                .foregroundStyle(AppTheme.blue)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 46)
                .background(AppTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(AppTheme.blue, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isButton)
        } else {
            Text(title)
                .font(AppTheme.system(15, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 46)
                .accessibilityLabel(title)
                .accessibilityAddTraits(.isStaticText)
                .accessibilityRemoveTraits(.isButton)
        }
    }
}

struct PickupConfirmedView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var flow: BorrowingFlowStore
    @EnvironmentObject private var lifecycle: LoanLifecycleViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 13) {
                    LoanHeader(title: "Loan activated", subtitle: "Evidence receipt ready") { router.go(to: .loanList) }
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.shield").font(.system(size: 38, weight: .light))
                            .foregroundStyle(AppTheme.green).frame(width: 64, height: 64)
                            .overlay(Circle().stroke(AppTheme.green, lineWidth: 2))
                        Text("Pickup confirmed").font(AppTheme.rounded(24, weight: .heavy)).foregroundStyle(AppTheme.blue)
                    }.frame(maxWidth: .infinity).padding(.top, 6)
                    LoanProgressBar(active: 1)
                    Label("Saved here and synced securely", systemImage: "checkmark.icloud")
                        .font(.system(size: 12)).foregroundStyle(AppTheme.green).padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading).background(AppTheme.green.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 8))
                    if let loan = flow.reservation {
                        LoanCard {
                            VStack(spacing: 11) {
                                HStack { title("Active-loan receipt"); Spacer(); LoanBadge(title: "Active") }
                                BorrowingInfoRow(label: "Evidence photos", value: "\(lifecycle.pickupPhotos.count) originals")
                                BorrowingInfoRow(label: "Captured", value: lifecycle.pickupPhotos.first?.capturedAt.borrowingShortDate ?? "Recorded")
                                BorrowingInfoRow(label: "Pickup area", value: loan.pickupAddress)
                                BorrowingInfoRow(label: "Evidence ID", value: loan.receipt)
                                BorrowingInfoRow(label: "Cloud receipt", value: "Synced")
                            }
                        }
                        LoanCard {
                            VStack(alignment: .leading, spacing: 11) {
                                title("Audit trail")
                                audit(lifecycle.pickupPhotos.first?.capturedAt, "Inspection started")
                                audit(lifecycle.pickupPhotos.last?.capturedAt, "Eight angles recorded")
                                audit(loan.activatedAt, "Both parties acknowledged")
                                audit(loan.activatedAt, "Pending → Active", highlighted: true)
                            }
                        }
                        LoanNotice(icon: "checkmark.shield", title: "Your \(loan.totalHold) LC hold remains protected",
                                   message: "The loan is settled only after the returned condition is approved. Deposit credits release at settlement.")
                    }
                    AccountSaveStatus(error: lifecycle.errorMessage, success: nil)
                }.padding(.horizontal, 18).padding(.vertical, 8)
            }
            PrimaryButton(title: "Open active loan", systemImage: "arrow.right") { router.go(to: .activeLoan) }
                .padding(.horizontal, 18).padding(.vertical, 12).background(AppTheme.surface)
        }.background(AppTheme.background)
    }

    private func title(_ value: String) -> some View {
        Text(value).font(AppTheme.rounded(14, weight: .bold)).foregroundStyle(AppTheme.blue)
    }
    private func audit(_ date: Date?, _ value: String, highlighted: Bool = false) -> some View {
        HStack(spacing: 11) {
            Text(date?.formatted(.dateTime.hour().minute()) ?? "—").font(.system(size: 10, design: .monospaced)).foregroundStyle(AppTheme.secondaryText).frame(width: 44, alignment: .leading)
            Circle().fill(highlighted ? AppTheme.yellow : AppTheme.blue).frame(width: 7, height: 7)
            Text(value).font(.system(size: 13, weight: highlighted ? .bold : .regular)).foregroundStyle(highlighted ? AppTheme.blue : AppTheme.text)
        }
    }
}

struct ActiveLoanView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var flow: BorrowingFlowStore
    @EnvironmentObject private var lifecycle: LoanLifecycleViewModel
    @State private var showOptions = false
    private var loan: ReservationRecord? { flow.reservation }
    private var isBorrower: Bool { loan?.borrowerID == dependencies.authenticationService.currentUserID }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 13) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Active loan").font(AppTheme.rounded(22, weight: .heavy)).foregroundStyle(AppTheme.blue)
                            Text(loan?.toolName ?? "").font(.system(size: 13)).foregroundStyle(AppTheme.green)
                        }
                        Spacer()
                        Button("Help") { showOptions = true }.font(.system(size: 13, weight: .bold)).foregroundStyle(AppTheme.blue)
                    }
                    LoanProgressBar(active: 1)
                    if let loan {
                        hero(loan)
                        LoanCard { LoanParticipantRow(name: isBorrower ? loan.ownerName : loan.borrowerName,
                                                     detail: isBorrower ? "Owner · message about your loan" : "Borrower · return in progress", badge: isBorrower ? "Owner" : "Borrower") }
                        PickupMapCard(coordinate: loan.toolSnapshot.coordinate, label: "Drop-off · \(loan.pickupAddress)").frame(height: 112)
                        HStack(spacing: 8) {
                            stat("\(loan.totalHold) LC", "Held")
                            stat("\(lifecycle.pickupPhotos.count)", "Photos")
                            stat(loan.returnAt.formatted(.dateTime.weekday(.abbreviated).hour()), "Return")
                        }
                        if let notice = NonReturnPolicy.notice(for: loan, now: Date()) {
                            LoanNotice(icon: "clock", title: notice.title, message: notice.message, color: AppTheme.coral, background: AppTheme.yellow.opacity(0.13))
                        }
                        if !isBorrower {
                            LoanNotice(icon: "person.badge.clock", title: "Loan in progress", message: "The borrower records return evidence. You will review the paired photos before approval.")
                        }
                    }
                    AccountSaveStatus(error: lifecycle.errorMessage, success: nil)
                }.padding(.horizontal, 18).padding(.vertical, 12)
            }
            if isBorrower {
                PrimaryButton(title: (loan?.lifecycleStage ?? lifecycle.stage) == .active ? "Start return" : "Continue return", systemImage: "arrow.up.circle", enabled: !lifecycle.isLoading) {
                    Task {
                        let stage = loan?.lifecycleStage ?? lifecycle.stage
                        if stage == .active {
                            lifecycle.configure(reservationID: loan?.id ?? lifecycle.reservationID, stage: .active)
                            if await lifecycle.move(to: .returnTransit, using: dependencies.loanLifecycleRepository) { router.go(to: .toolReturn) }
                        } else {
                            router.go(to: stage == .returnInspection ? .returnCapture : .toolReturn)
                        }
                    }
                }.padding(.horizontal, 18).padding(.vertical, 12).background(AppTheme.surface)
            } else {
                LoanOutlineButton(title: "Back to my loans") { router.go(to: .loanList) }.padding(18)
            }
        }.background(AppTheme.background)
            .sheet(isPresented: $showOptions) { LoanOptionsView() }
            .onChange(of: loan?.lifecycleStage) { _, stage in
                if stage == .awaitingReview { router.go(to: .ownerReview) }
                else if stage == .completed { router.go(to: .loanCompleted) }
            }
    }

    private func hero(_ loan: ReservationRecord) -> some View {
        ZStack(alignment: .bottomLeading) {
            AppTheme.blue.opacity(0.12)
            if let photo = lifecycle.pickupPhotos.first, let image = lifecycle.image(for: photo) {
                Image(uiImage: image).resizable().scaledToFill().frame(height: 190).clipped()
            } else {
                CatalogToolArtwork(tool: loan.toolSnapshot).padding(20)
            }
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 5) {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    let hours = max(0, Int(loan.returnAt.timeIntervalSince(context.date) / 3600))
                    let headline = NonReturnPolicy.notice(for: loan, now: context.date)?.title
                        ?? (hours > 0 ? "\(hours / 24)d \(hours % 24)h left" : "Return due")
                    Text(headline)
                        .font(AppTheme.rounded(30, weight: .heavy)).foregroundStyle(Color.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                }
                Text("Return \(loan.returnAt.borrowingDateTime)").font(.system(size: 12)).foregroundStyle(Color.white)
            }.padding(14)
        }.frame(height: 190).clipped()
            .overlay(alignment: .topLeading) { LoanBadge(title: "Active").padding(12).background(AppTheme.surface.opacity(0.92)) }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        LoanCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(value).font(.system(size: 13, weight: .bold)).foregroundStyle(AppTheme.blue).lineLimit(1).minimumScaleFactor(0.75)
                Text(label).font(.system(size: 10.5)).foregroundStyle(AppTheme.green)
            }
        }
    }
}

struct OwnerReviewView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var flow: BorrowingFlowStore
    @EnvironmentObject private var lifecycle: LoanLifecycleViewModel
    @StateObject private var model = CommunityViewModel()
    @State private var enlargedImage: UIImage?
    @State private var showImage = false
    @State private var showIssue = false
    @State private var issue = ""
    private var loan: ReservationRecord? { flow.reservation }
    private var isOwner: Bool { loan?.ownerID == dependencies.authenticationService.currentUserID }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        LoanHeader(title: "Review returned condition", subtitle: isOwner ? "Owner view · \(loan?.borrowerName ?? "Borrower") is waiting" : "Waiting for the owner's review") { router.go(to: .loanList) }
                        if isOwner { Button { showIssue = true } label: { Image(systemName: "ellipsis").foregroundStyle(AppTheme.blue).padding(.top, 9) }.accessibilityLabel("Flag condition issue") }
                    }
                    if let loan {
                        LoanCard {
                            HStack(spacing: 10) {
                                CatalogToolArtwork(tool: loan.toolSnapshot).frame(width: 62, height: 62).background(AppTheme.blue.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(loan.toolName).font(AppTheme.rounded(16, weight: .bold)).foregroundStyle(AppTheme.blue)
                                    Text("Returned by \(loan.borrowerName) · \(loan.submittedForReviewAt?.formatted(.dateTime.hour().minute()) ?? "Submitted")")
                                        .font(.system(size: 12.5)).foregroundStyle(AppTheme.green)
                                }
                                Spacer(minLength: 0)
                                LoanBadge(title: loan.reviewFlag == nil ? "Needs review" : "Paused", warning: true)
                            }
                        }
                        evidenceCard
                        LoanCard {
                            VStack(spacing: 10) {
                                BorrowingInfoRow(label: "Condition note", value: lifecycle.conditionNote)
                                BorrowingInfoRow(label: "Return location", value: loan.arrivalAt == nil ? "Not recorded" : "Arrival recorded")
                                BorrowingInfoRow(label: "Evidence sync", value: "\(lifecycle.pickupPhotos.count + lifecycle.returnPhotos.count)/16 originals")
                            }
                        }
                        LoanNotice(icon: "arrow.left.arrow.right", title: "What happens next",
                                   message: "Approve to complete the loan, settle \(loan.rentalCredits + loan.serviceCredits) LC, and release \(loan.depositCredits) LC. Flagging pauses settlement for both people.", color: AppTheme.blue, background: AppTheme.blue.opacity(0.08))
                        if let flag = loan.reviewFlag { LoanNotice(icon: "exclamationmark.triangle", title: "Settlement paused", message: flag, color: AppTheme.coral, background: AppTheme.yellow.opacity(0.13)) }
                    }
                    AccountSaveStatus(error: model.error ?? lifecycle.errorMessage, success: nil)
                }.padding(.horizontal, 18).padding(.vertical, 8)
            }
            PrimaryButton(title: isOwner ? "Approve condition" : "Waiting for owner approval", systemImage: "checkmark.shield",
                          enabled: isOwner && loan?.reviewFlag == nil && loan?.lifecycleStage == .awaitingReview && lifecycle.returnPhotos.count == 8 && !lifecycle.isLoading) {
                guard let loan else { return }
                Task {
                    if await lifecycle.complete(settlement: LoanSettlement(totalHold: loan.totalHold, loanCharge: loan.rentalCredits + loan.serviceCredits, depositRefund: loan.depositCredits), using: dependencies.loanLifecycleRepository) {
                        do { try await dependencies.refreshSelectedLoan(); router.go(to: .loanCompleted) }
                        catch { model.error = error.localizedDescription }
                    }
                }
            }.padding(.horizontal, 18).padding(.vertical, 12).background(AppTheme.surface)
        }.background(AppTheme.background)
            .sheet(isPresented: $showImage) { if let enlargedImage { EvidencePhotoDetailView(image: enlargedImage) } }
            .sheet(isPresented: $showIssue) {
                NavigationStack {
                    Form {
                        TextField("Describe the issue", text: $issue, axis: .vertical).lineLimit(3...8)
                        Text("This pauses settlement for human review. No automatic damage charge is made.").font(.footnote)
                        Button("Flag issue and pause settlement", role: .destructive) {
                            guard let loan else { return }
                            Task {
                                if await model.perform({ try await dependencies.communityRepository.flagReturn(reservationID: loan.id, reason: issue) }) { showIssue = false }
                            }
                        }.disabled(issue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || issue.count > 500 || model.isLoading)
                        AccountSaveStatus(error: model.error, success: nil)
                    }.navigationTitle("Condition issue").toolbar { Button("Close") { showIssue = false } }
                }.presentationDetents([.medium, .large])
            }
            .onChange(of: loan?.status) { _, status in if status == .completed { router.go(to: .loanCompleted) } }
    }

    private var evidenceCard: some View {
        LoanCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack { Text("Paired evidence"); Spacer(); Text("\(min(lifecycle.pickupPhotos.count, lifecycle.returnPhotos.count)) pairs") }
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(AppTheme.blue)
                TabView {
                    ForEach(EvidenceAngle.allCases) { angle in
                        HStack(spacing: 8) {
                            photo(phase: .pickup, angle: angle)
                            photo(phase: .return, angle: angle)
                        }.padding(.bottom, 24)
                    }
                }.frame(height: 152).tabViewStyle(.page(indexDisplayMode: .always))
                LoanNotice(icon: "checkmark.magnifyingglass", title: "Review the same angle",
                           message: "Compare the original pickup and return photos. Existing notes: \(lifecycle.conditionNote)")
            }
        }
    }

    private func photo(phase: EvidencePhase, angle: EvidenceAngle) -> some View {
        let evidence = lifecycle.photos(for: phase).first { $0.angle == angle }
        let image = evidence.flatMap { lifecycle.image(for: $0) }
        let caption = "\(phase == .pickup ? "Pickup" : "Return") · \(angle.title)"
        return VStack(spacing: 4) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 8).fill(AppTheme.blue.opacity(0.10))
                if let image {
                    Image(uiImage: image).resizable().scaledToFit().padding(4)
                        .accessibilityLabel(caption)
                        .accessibilityAddTraits(.isImage)
                        .accessibilityRemoveTraits(.isButton)
                } else {
                    Image(systemName: "photo").foregroundStyle(AppTheme.blue).frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel("No \(caption) photo yet")
                        .accessibilityAddTraits(.isImage)
                        .accessibilityRemoveTraits(.isButton)
                }
                Text(caption).font(.system(size: 9, design: .monospaced)).foregroundStyle(AppTheme.blue).padding(8).background(AppTheme.surface.opacity(0.92))
                    .accessibilityHidden(true)
            }.clipShape(RoundedRectangle(cornerRadius: 8))
            if image != nil {
                Button("View") {
                    enlargedImage = image
                    showImage = true
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.blue)
                .accessibilityLabel("View \(caption) photo")
            }
        }
    }
}

struct LoanCompletedView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var flow: BorrowingFlowStore
    @StateObject private var model = CommunityViewModel()
    @State private var rating: LoanRating?
    private var loan: ReservationRecord? { flow.reservation }
    private var otherName: String { loan?.ownerID == dependencies.authenticationService.currentUserID ? loan?.borrowerName ?? "Borrower" : loan?.ownerName ?? "Owner" }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Loan completed").font(AppTheme.rounded(23, weight: .heavy)).foregroundStyle(AppTheme.blue)
                        Text("Receipt, history & rating").font(.system(size: 13, weight: .semibold)).foregroundStyle(AppTheme.green)
                    }
                    Spacer()
                    Button("Done") { router.go(to: .home) }.font(.system(size: 13, weight: .bold)).foregroundStyle(AppTheme.blue)
                }
                if let loan {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle").font(.system(size: 42, weight: .light)).foregroundStyle(AppTheme.green)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Settled \(loan.completedAt?.formatted(.dateTime.hour().minute()) ?? "successfully")").font(AppTheme.rounded(18, weight: .heavy)).foregroundStyle(AppTheme.blue)
                            Text("TXN \(loan.receipt)").font(.system(size: 9, design: .monospaced)).foregroundStyle(AppTheme.green)
                        }
                        Spacer(minLength: 0); LoanBadge(title: "Completed")
                    }
                    LoanProgressBar(active: 2)
                    LoanCard {
                        VStack(spacing: 10) {
                            HStack { section("Credit settlement"); Spacer(); Text("Receipt").font(.system(size: 12, weight: .bold)).foregroundStyle(AppTheme.blue) }
                            BorrowingInfoRow(label: "Pending Hold", value: "\(loan.totalHold) LC released")
                            BorrowingInfoRow(label: "\(loan.borrowerName) · loan", value: "−\(loan.settledCharge ?? loan.rentalCredits + loan.serviceCredits) LC", valueColor: AppTheme.coral)
                            BorrowingInfoRow(label: "\(loan.ownerName) · settlement", value: "+\(loan.receiptOwnerCredits) LC", valueColor: AppTheme.green)
                            BorrowingInfoRow(label: "Service & protection", value: "\(loan.receiptServiceCredits) LC")
                            BorrowingInfoRow(label: "Deposit refund", value: "+\(loan.receiptRefund) LC")
                            if let date = loan.completedAt { Text(date.borrowingDateTime).font(.system(size: 10, design: .monospaced)).foregroundStyle(AppTheme.green).frame(maxWidth: .infinity, alignment: .leading) }
                        }
                    }
                    LoanCard {
                        VStack(alignment: .leading, spacing: 11) {
                            section("Completed timeline")
                            HStack {
                                timeline("Reserved", date: loan.requestedAt)
                                timeline("Active", date: loan.activatedAt)
                                timeline("Returned", date: loan.submittedForReviewAt)
                                timeline("Completed", date: loan.completedAt, completed: true)
                            }
                        }
                    }
                    LoanCard {
                        VStack(alignment: .leading, spacing: 13) {
                            HStack { section("Your rating for \(otherName)"); Spacer(); if rating != nil { LoanBadge(title: "Submitted") } }
                            if let rating {
                                HStack(spacing: 4) { ForEach(1...5, id: \.self) { index in Image(systemName: index <= rating.stars ? "star.fill" : "star").foregroundStyle(AppTheme.blue) } }
                                if !rating.comment.isEmpty { Text(rating.comment).font(.system(size: 13)).foregroundStyle(AppTheme.text) }
                            } else {
                                Button { router.go(to: .loanRating) } label: {
                                    HStack(spacing: 5) { ForEach(0..<5, id: \.self) { _ in Image(systemName: "star").font(.title3) }; Text("Rate your neighbor").font(.caption.bold()) }
                                }.foregroundStyle(AppTheme.blue)
                            }
                            Button { router.go(to: .helpSupport) } label: { Label("Report a private issue", systemImage: "lock").font(.system(size: 11)).foregroundStyle(AppTheme.green) }
                        }
                    }
                }
                AccountSaveStatus(error: model.error, success: nil)
            }.padding(.horizontal, 18).padding(.vertical, 10)
        }.background(AppTheme.background).task(id: loan?.id) {
            guard let id = loan?.id else { return }
            _ = await model.perform { rating = try await dependencies.communityRepository.myRating(reservationID: id) }
        }
    }

    private func section(_ value: String) -> some View { Text(value).font(AppTheme.rounded(14, weight: .bold)).foregroundStyle(AppTheme.blue) }
    private func timeline(_ label: String, date: Date?, completed: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Circle().fill(completed ? AppTheme.yellow : AppTheme.blue).frame(width: 8, height: 8)
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(AppTheme.blue)
            Text(date?.formatted(.dateTime.month(.abbreviated).day()) ?? "—").font(.system(size: 9)).foregroundStyle(AppTheme.green)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Secondary functions stay available without replacing the reference layouts.
struct LoanOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var flow: BorrowingFlowStore
    @StateObject private var model = CommunityViewModel()
    @State private var extendedReturn = Date()
    private var loan: ReservationRecord? { flow.reservation }
    private var isOwner: Bool { loan?.ownerID == dependencies.authenticationService.currentUserID }

    var body: some View {
        NavigationStack {
            Form {
                if let loan {
                    Section("Loan") {
                        Button("Message \(isOwner ? loan.borrowerName : loan.ownerName)") {
                            dismiss()
                            router.chatReturnRoute = .reservationPending
                            router.go(to: .loanChat)
                        }
                        Button("Return calendar reminder") { Task { _ = await model.perform { try await dependencies.eventReminderService.addReturnReminder(for: loan) } } }
                    }
                    if loan.lifecycleStage == .active {
                        Section("Agreed extension") {
                            if let date = loan.extensionRequestedAt {
                                Text("Requested until \(date.borrowingDateTime) · \(loan.extensionCredits) LC")
                                if isOwner {
                                    Button("Accept extension") { respond(true, loan: loan) }
                                    Button("Decline extension", role: .destructive) { respond(false, loan: loan) }
                                }
                            } else if !isOwner {
                                DatePicker("Return until", selection: $extendedReturn, in: loan.returnAt.addingTimeInterval(3600)...loan.returnAt.addingTimeInterval(7 * 86400))
                                Button("Request extension") { Task { _ = await model.perform { try await dependencies.communityRepository.requestExtension(reservationID: loan.id, returnAt: extendedReturn) } } }
                            }
                        }.disabled(model.isLoading)
                    }
                    if LoanRules.canOpenNonReturnCase(loan, userID: dependencies.authenticationService.currentUserID ?? "", now: Date()) {
                        let title = NonReturnPolicy.notice(for: loan, now: Date())?.status == .escalationEligible
                            ? "Escalate for human review"
                            : "Open a non-return case"
                        Button(title) { dismiss(); router.go(to: .nonReturnCase) }
                    }
                }
                Button("Help & Support") { dismiss(); router.go(to: .helpSupport) }
                Button("All my loans") { dismiss(); router.go(to: .loanList) }
                AccountSaveStatus(error: model.error, success: model.success)
            }.navigationTitle("Loan help").toolbar { Button("Done") { dismiss() } }
                .onAppear { extendedReturn = loan?.returnAt.addingTimeInterval(86400) ?? Date() }
        }.presentationDetents([.medium, .large])
    }
    private func respond(_ accepted: Bool, loan: ReservationRecord) {
        Task { _ = await model.perform { try await dependencies.communityRepository.respondToExtension(reservationID: loan.id, accepted: accepted) } }
    }
}
