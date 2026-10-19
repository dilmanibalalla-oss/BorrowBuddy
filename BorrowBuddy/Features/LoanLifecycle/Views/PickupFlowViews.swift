import AVFoundation
import SwiftUI
import UIKit

struct PickupMeetView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var flow: BorrowingFlowStore
    @EnvironmentObject private var lifecycle: LoanLifecycleViewModel
    @State private var isRefreshing = false
    @State private var refreshError: String?

    private var blocker: PickupInspectionBlocker? {
        PickupInspectionEligibility.blocker(for: flow.reservation,
            userID: dependencies.authenticationService.currentUserID,
            kitConfirmed: lifecycle.kitConfirmed, wearReviewed: lifecycle.wearReviewed)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    LoanHeader(title: "Meet for pickup", subtitle: flow.quote.pickupAt.borrowingDateTime) {
                        router.go(to: .reservationPending)
                    }
                    LoanProgressBar(active: 0)
                    if let loan = flow.reservation, !loan.pickupAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        PickupMapCard(coordinate: loan.toolSnapshot.coordinate,
                                      label: "Designated pickup · \(loan.pickupAddress)")
                            .frame(height: 180)
                    } else {
                        LoanNotice(icon: "mappin.slash", title: "Pickup details not recorded",
                                   message: "This reservation has no pickup address. Refresh it or open a new reservation from an existing listing; a placeholder map is not a verified pickup spot.")
                    }
                    peopleCard
                    checklistCard
                    if let blocker { blockerNotice(blocker) }
                    LoanNotice(
                        icon: "person.badge.shield.checkmark",
                        title: "Meet at the listed spot",
                        message: "If either person or location doesn't match, pause and contact support.",
                        color: AppTheme.green,
                        background: AppTheme.yellow.opacity(0.14)
                    )
                    if let errorMessage = lifecycle.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.coral)
                    }
                    AccountSaveStatus(error: refreshError, success: nil)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
            }

            PrimaryButton(
                title: lifecycle.isLoading ? "Starting..." : "Begin inspection together",
                enabled: !lifecycle.isLoading && !isRefreshing && blocker == nil
            ) {
                Task {
                    guard blocker == nil, let loan = flow.reservation else { return }
                    lifecycle.configure(reservationID: loan.id, stage: loan.lifecycleStage)
                    if lifecycle.stage == .pickupInspection { router.go(to: .conditionGuide); return }
                    if await lifecycle.move(
                        to: .pickupInspection,
                        using: dependencies.loanLifecycleRepository
                    ) {
                        router.go(to: .conditionGuide)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
            .background(Color.white)
        }
        .background(AppTheme.background)
        .refreshable { await refreshReservation() }
    }

    @ViewBuilder
    private func blockerNotice(_ blocker: PickupInspectionBlocker) -> some View {
        switch blocker {
        case .missingReservation:
            LoanNotice(icon: "tray", title: "No saved reservation selected",
                       message: "Open your reservation from Home or your loan history before starting pickup.")
            LoanOutlineButton(title: "Open my reservations") { router.go(to: .loanList) }
        case .awaitingOwner:
            LoanNotice(icon: "person.badge.clock", title: "Waiting for owner acceptance",
                       message: "Both checklist checks are not enough. The owner must sign in to their own account, open this request under Lending, and tap Accept request.")
            HStack {
                Button("View request") { router.go(to: .reservationPending) }
                Spacer()
                Button(isRefreshing ? "Refreshing…" : "Refresh approval") { Task { await refreshReservation() } }
                    .disabled(isRefreshing)
            }.font(.system(size: 13, weight: .semibold)).foregroundStyle(AppTheme.blue)
        case .wrongAccount:
            LoanNotice(icon: "person.crop.circle", title: "Borrower account required",
                       message: "Only the borrower starts inspection. The owner accepts the request and later reviews the shared baseline from their own account.")
            LoanOutlineButton(title: "View reservation") { router.go(to: .reservationPending) }
        case .wrongStage:
            LoanNotice(icon: "arrow.triangle.2.circlepath", title: "This loan is not awaiting pickup",
                       message: "Open its current stage from your loan history instead of starting another inspection.")
            LoanOutlineButton(title: "Back to my loans") { router.go(to: .loanList) }
        case .incompleteChecklist:
            Text("Confirm the included items and review existing wear to enable inspection.")
                .font(.system(size: 12)).foregroundStyle(AppTheme.green)
        }
    }

    private func refreshReservation() async {
        guard !isRefreshing else { return }
        isRefreshing = true; refreshError = nil
        defer { isRefreshing = false }
        do { try await dependencies.refreshSelectedLoan() }
        catch { refreshError = error.localizedDescription }
    }

    private var peopleCard: some View {
        LoanCard {
            VStack(alignment: .leading, spacing: 13) {
                Text("Confirm who's here")
                    .font(AppTheme.rounded(14, weight: .heavy))
                    .foregroundStyle(AppTheme.blue)
                personRow(initials: String((flow.reservation?.borrowerName ?? "Borrower").prefix(2)).uppercased(), name: flow.reservation?.borrowerName ?? "Borrower", detail: "Borrower account")
                personRow(initials: String((flow.reservation?.ownerName ?? "Owner").prefix(2)).uppercased(), name: flow.reservation?.ownerName ?? "Owner", detail: "Owner account · confirm identity in person")
            }
        }
    }

    private func personRow(initials: String, name: String, detail: String) -> some View {
        HStack(spacing: 11) {
            Circle()
                .fill(AppTheme.yellow.opacity(0.45))
                .frame(width: 43, height: 43)
                .overlay {
                    Text(initials)
                        .font(AppTheme.rounded(11, weight: .heavy))
                        .foregroundStyle(AppTheme.blue)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.green)
            }
            Spacer()
            Text("• Participant")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.green)
                .padding(.horizontal, 9)
                .frame(height: 25)
                .background(AppTheme.green.opacity(0.10))
        }
    }

    private var checklistCard: some View {
        LoanCard {
            VStack(alignment: .leading, spacing: 11) {
                Text("Pickup checklist")
                    .font(AppTheme.rounded(14, weight: .heavy))
                    .foregroundStyle(AppTheme.blue)
                checklistRow("Confirm \(flow.selectedTool.name) and included items", checked: lifecycle.kitConfirmed) {
                    lifecycle.kitConfirmed.toggle()
                }
                checklistRow("Review existing wear together", checked: lifecycle.wearReviewed) {
                    lifecycle.wearReviewed.toggle()
                }
                checklistStatus("Capture 8 required angles", checked: lifecycle.pickupPhotos.count == 8)
                checklistStatus("Both acknowledge baseline", checked: flow.reservation?.status == .active)
                Text("The last two checks update automatically after photos and separate acknowledgements.")
                    .font(.system(size: 11)).foregroundStyle(AppTheme.green)
            }
        }
    }

    private func checklistStatus(_ title: String, checked: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: checked ? "checkmark.square.fill" : "square")
                .font(.system(size: 21)).foregroundStyle(checked ? AppTheme.blue : AppTheme.border)
            Text(title).font(.system(size: 13)).foregroundStyle(AppTheme.text)
            Spacer()
        }.accessibilityElement(children: .combine)
            .accessibilityValue(checked ? "Complete" : "Updates after inspection")
    }

    private func checklistRow(_ title: String, checked: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 21))
                    .foregroundStyle(checked ? AppTheme.blue : AppTheme.border)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.text)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

struct ConditionGuideView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var lifecycle: LoanLifecycleViewModel
    @State private var cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 13) {
                    LoanHeader(
                        title: "Document condition",
                        subtitle: "Before the loan becomes Active"
                    ) {
                        router.go(to: .pickupMeet)
                    }
                    hero
                    benefit("camera.aperture", "8 guided angles", "Show the whole item, serial label, and wear points.")
                    benefit("clock.badge.checkmark", "Timestamped evidence", "Photos include the capture time. Both people review the same eight angles.")
                    benefit("person.2", "Shared baseline", "You and the owner must acknowledge separately before activation.")
                    permissionCard
                    LoanNotice(
                        icon: "slider.horizontal.3",
                        title: "Prefer not to allow camera?",
                        message: "Enable camera access in iPhone Settings. Each person acknowledges using their own signed-in account."
                    )
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
            }

            PrimaryButton(title: "Allow camera & continue") {
                Task {
                    if !UIImagePickerController.isSourceTypeAvailable(.camera) {
                        router.go(to: .baselineCapture)
                        return
                    }
                    await lifecycle.requestCameraAccess()
                    cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
                    if cameraStatus == .authorized { router.go(to: .baselineCapture) }
                    else if let url = URL(string: UIApplication.openSettingsURLString) { await UIApplication.shared.open(url) }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
            .background(Color.white)
        }
        .background(AppTheme.background)
    }

    private var hero: some View {
        VStack(spacing: 14) {
            Circle()
                .fill(Color.white)
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 31, weight: .light))
                        .foregroundStyle(AppTheme.blue)
                }
            Text("Photos protect both people")
                .font(AppTheme.rounded(21, weight: .heavy))
                .foregroundStyle(AppTheme.blue)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 170)
        .background(AppTheme.blue.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }

    private func benefit(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.blue)
                .frame(width: 30, height: 30)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                Text(detail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.green)
                    .lineSpacing(2)
            }
        }
    }

    private var permissionCard: some View {
        LoanCard {
            VStack(spacing: 10) {
                BorrowingInfoRow(
                    label: "Camera",
                    value: cameraStatus == .authorized ? "Allowed" : "Not allowed",
                    icon: "camera",
                    valueColor: cameraStatus == .authorized ? AppTheme.blue : AppTheme.coral
                )
                Text("Return arrival is checked separately using location permission.").font(.caption).foregroundStyle(AppTheme.green)
            }
        }
    }
}

struct EvidenceCaptureView: View {
    let phase: EvidencePhase
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var lifecycle: LoanLifecycleViewModel
    @State private var showPicker = false

    private var photos: [EvidencePhoto] { lifecycle.photos(for: phase) }
    private var currentIndex: Int { min(photos.count, EvidenceAngle.allCases.count - 1) }
    private var currentAngle: EvidenceAngle { EvidenceAngle.allCases[currentIndex] }
    private var isComplete: Bool { photos.count == EvidenceAngle.allCases.count }
    private var isPickup: Bool { phase == .pickup }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                captureHeader
                progress
                if !isPickup {
                    matchCard
                }
                cameraFrame
                captureDetails
                controls
                if let errorMessage = lifecycle.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.coral)
                        .padding(.top, 12)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
        }
        .background(isPickup ? Color(red: 0.08, green: 0.14, blue: 0.17) : AppTheme.background)
        .sheet(isPresented: $showPicker) {
            EvidenceImagePicker { image in
                lifecycle.capture(image, phase: phase)
            }
            .ignoresSafeArea()
        }
    }

    private var captureHeader: some View {
        HStack(alignment: .top) {
            Button {
                router.go(to: isPickup ? .conditionGuide : .arrivalConfirmed)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 32, height: 32)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(isPickup ? "Baseline photos" : "Return photos")
                    .font(AppTheme.rounded(22, weight: .heavy))
                Text("\(min(photos.count + 1, 8)) of 8 · \(currentAngle.title)")
                    .font(.system(size: 13))
            }
            Spacer()
            Button("Exit") {
                router.go(to: isPickup ? .pickupMeet : .activeLoan)
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(isPickup ? AppTheme.yellow : AppTheme.blue)
        }
        .foregroundStyle(isPickup ? Color.white : AppTheme.blue)
        .padding(.top, 9)
    }

    private var progress: some View {
        HStack(spacing: 5) {
            ForEach(0..<8, id: \.self) { index in
                Capsule()
                    .fill(index < photos.count ? AppTheme.blue : index == photos.count ? AppTheme.yellow : AppTheme.border)
                    .frame(height: 4)
            }
        }
        .padding(.vertical, 15)
    }

    private var matchCard: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.blue.opacity(0.10))
                .frame(width: 74, height: 57)
                .overlay {
                    Text("BASELINE")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(AppTheme.blue)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text("Match this angle")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.blue)
                Text(currentAngle.instruction)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.text)
            }
            Spacer()
        }
        .padding(10)
        .overlay {
            RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 1.5)
        }
        .padding(.bottom, 12)
    }

    private var cameraFrame: some View {
        ZStack {
            Color(isPickup ? UIColor(red: 0.12, green: 0.20, blue: 0.23, alpha: 1) : .black)
            if let last = photos.last, let image = lifecycle.image(for: last) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
            grid
            VStack {
                Spacer()
                Text(isPickup ? currentAngle.instruction : "Return area · \(Date().formatted(date: .omitted, time: .standard))")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 48)
                    .background(Color.black.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(16)
            }
        }
        .frame(height: isPickup ? 470 : 380)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(isPickup ? Color.clear : AppTheme.blue, lineWidth: 2)
        }
        .clipped()
    }

    private var grid: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: proxy.size.width / 3, y: 0))
                path.addLine(to: CGPoint(x: proxy.size.width / 3, y: proxy.size.height))
                path.move(to: CGPoint(x: proxy.size.width * 2 / 3, y: 0))
                path.addLine(to: CGPoint(x: proxy.size.width * 2 / 3, y: proxy.size.height))
                path.move(to: CGPoint(x: 0, y: proxy.size.height / 3))
                path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height / 3))
                path.move(to: CGPoint(x: 0, y: proxy.size.height * 2 / 3))
                path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height * 2 / 3))
            }
            .stroke(AppTheme.yellow.opacity(0.35), lineWidth: 0.7)
        }
    }

    private var captureDetails: some View {
        HStack {
            Label(Date().formatted(date: .omitted, time: .standard), systemImage: "clock")
            Spacer()
            Label(isPickup ? "Pickup evidence" : "Return evidence", systemImage: "camera")
        }
        .font(.system(size: 11.5))
        .foregroundStyle(isPickup ? Color.white.opacity(0.75) : AppTheme.secondaryText)
        .padding(.top, 12)
    }

    private var controls: some View {
        HStack {
            Button("Retake") {
                lifecycle.retakeLast(phase: phase)
                showPicker = true
            }
            .disabled(photos.isEmpty)
            Spacer()
            Button {
                if isComplete {
                    router.go(to: isPickup ? .baselineReview : .compareCondition)
                } else {
                    showPicker = true
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(AppTheme.blue, lineWidth: 4)
                        .frame(width: 69, height: 69)
                    Circle()
                        .stroke(AppTheme.yellow, lineWidth: 4)
                        .frame(width: 59, height: 59)
                    if isComplete {
                        Image(systemName: "checkmark")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.blue)
                    }
                }
            }
            Spacer()
            Button(isComplete ? "Review" : "Shots") {
                if isComplete {
                    router.go(to: isPickup ? .baselineReview : .compareCondition)
                }
            }
        }
        .font(.system(size: 12.5, weight: .bold))
        .foregroundStyle(isPickup ? Color.white : AppTheme.blue)
        .padding(.horizontal, 11)
        .padding(.top, 12)
    }
}

struct BaselineReviewView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var lifecycle: LoanLifecycleViewModel
    @EnvironmentObject private var flow: BorrowingFlowStore
    @StateObject private var model = CommunityViewModel()
    private var isBorrower: Bool { flow.reservation?.borrowerID == dependencies.authenticationService.currentUserID }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    LoanHeader(title: "Review baseline", subtitle: "8 required photos") {
                        router.go(to: .reservationPending)
                    }
                    photoGrid
                    conditionCard
                    acknowledgementCard
                    LoanNotice(
                        icon: "wifi.slash",
                        title: "Private evidence for both participants",
                        message: "Activation requires a successful cloud upload and a separate acknowledgement from each signed-in account."
                    )
                    if let errorMessage = lifecycle.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.coral)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
            }

            AccountSaveStatus(error: model.error, success: nil).padding(.horizontal, 18)
            PrimaryButton(title: lifecycle.isLoading ? "Saving..." : "I acknowledge this baseline", enabled: !lifecycle.isLoading && !model.isLoading && lifecycle.pickupPhotos.count == 8) {
                Task {
                    guard let loan = flow.reservation else { return }
                    if isBorrower && loan.acknowledgements.isEmpty {
                        guard await lifecycle.syncEvidence(phase: .pickup, using: dependencies.loanLifecycleRepository) else { return }
                    }
                    if await model.perform({
                        try await dependencies.communityRepository.acknowledgePickup(reservationID: loan.id)
                        try await dependencies.refreshSelectedLoan()
                    }) {
                        router.go(to: flow.reservation?.status == .active ? .pickupConfirmed : .reservationPending)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
            .background(Color.white)
        }
        .background(AppTheme.background)
    }

    private var photoGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 4), spacing: 7) {
            ForEach(EvidenceAngle.allCases) { angle in
                let photo = lifecycle.pickupPhotos.first { $0.angle == angle }
                EvidenceThumbnail(
                    title: angle.title,
                    image: photo.flatMap { lifecycle.image(for: $0) }
                )
            }
        }
    }

    private var conditionCard: some View {
        LoanCard {
            VStack(alignment: .leading, spacing: 7) {
                Text("Condition notes")
                    .font(AppTheme.rounded(14, weight: .heavy))
                    .foregroundStyle(AppTheme.blue)
                HStack(alignment: .top, spacing: 9) {
                    Text("1")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.blue)
                        .frame(width: 24, height: 24)
                        .background(AppTheme.yellow)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    VStack(alignment: .leading, spacing: 2) {
                        TextField("Existing wear or missing accessories", text: $lifecycle.conditionNote, axis: .vertical)
                            .font(.system(size: 13, weight: .bold))
                            .disabled(!isBorrower || !(flow.reservation?.acknowledgements.isEmpty ?? false))
                    }
                }
            }
        }
    }

    private var acknowledgementCard: some View {
        LoanCard {
            VStack(spacing: 9) {
                if let loan = flow.reservation {
                    BorrowingInfoRow(label: loan.borrowerName, value: loan.acknowledgements.contains(loan.borrowerID) ? "Acknowledged" : "Waiting")
                    BorrowingInfoRow(label: loan.ownerName, value: loan.acknowledgements.contains(loan.ownerID) ? "Acknowledged" : "Waiting")
                    BorrowingInfoRow(label: "Evidence set", value: loan.receipt)
                }
            }
        }
    }
}
