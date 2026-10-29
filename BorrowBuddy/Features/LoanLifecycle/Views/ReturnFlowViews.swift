import SwiftUI

struct ToolReturnView: View {
 @EnvironmentObject private var router: AppRouter
 @EnvironmentObject private var dependencies: AppDependencies
 @EnvironmentObject private var flow: BorrowingFlowStore
 @EnvironmentObject private var lifecycle: LoanLifecycleViewModel
 @StateObject private var location = ArrivalLocationService()
 @StateObject private var model = CommunityViewModel()
 var body: some View {
  VStack(spacing: 0) {
   ScrollView {
    VStack(alignment: .leading, spacing: 16) {
     LoanHeader(title: "Return to \(flow.reservation?.ownerName ?? "owner")", subtitle: "Due \(flow.quote.returnAt.borrowingDateTime)") { router.go(to: .activeLoan) }
     PickupMapCard(coordinate: flow.selectedTool.coordinate, label: "Drop-off boundary · 50 m", radiusVisible: true).frame(height: 280)
     LoanCard {
      VStack(alignment: .leading, spacing: 10) {
       HStack {
        Text("Approaching drop-off").font(AppTheme.rounded(16, weight: .bold)).foregroundStyle(AppTheme.blue)
        Spacer()
        LoanBadge(title: location.distance(to: flow.selectedTool.coordinate).map { "\(Int($0)) m away" } ?? "Checking")
       }
       if let distance = location.distance(to: flow.selectedTool.coordinate) {
        ProgressView(value: min(1, max(0, 1 - distance / 500))).tint(AppTheme.blue)
        Text(distance <= 50 ? "You're near the drop-off. Confirm arrival below." : "Follow the map to the designated drop-off area.").font(.system(size: 12))
       } else { Text("Your current position is not available yet.").font(.system(size: 12)) }
       if let accuracy = location.location?.horizontalAccuracy { Text("GPS accuracy: \(Int(accuracy)) meters").font(.caption) }
       Button(location.isLoading ? "Checking location..." : "Refresh current location") { location.refresh() }.disabled(location.isLoading)
      }
     }
     LoanNotice(icon: "location.circle", title: "Foreground arrival check",
       message: "We check your distance on this device when you tap. Only the arrival time and GPS accuracy are saved, not your route. Location is a device signal, not proof of handoff.")
     AccountSaveStatus(error: model.error ?? location.error, success: nil)
    }.padding(18)
   }
   PrimaryButton(title: model.isLoading ? "Confirming..." : "I'm here", systemImage: "hand.raised", enabled: !model.isLoading && !location.isLoading) {
    guard let loan = flow.reservation else { return }
    Task {
     if await model.perform({
      let accuracy = try arrivalAccuracy()
      try await dependencies.communityRepository.recordArrival(reservationID: loan.id, accuracy: accuracy)
     }) {
      lifecycle.configure(reservationID: loan.id, stage: .returnInspection)
      var updated = loan; updated.arrivalAt = Date(); updated.arrivalAccuracy = location.location?.horizontalAccuracy ?? 10
      updated.lifecycleStage = .returnInspection; flow.reservation = updated
      router.go(to: .arrivalConfirmed)
     }
    }
   }.padding(18)
  }.background(AppTheme.background).task { location.refresh() }
 }

 private func arrivalAccuracy() throws -> Double {
  #if targetEnvironment(simulator)
  return 10
  #else
  return try location.verifiedAccuracy(at: flow.selectedTool.coordinate)
  #endif
 }
}

struct ArrivalConfirmedView: View {
 @EnvironmentObject private var router: AppRouter
 @EnvironmentObject private var flow: BorrowingFlowStore
 var body: some View {
  VStack(spacing: 0) {
   ScrollView {
    VStack(alignment: .leading, spacing: 14) {
     LoanHeader(title: "Arrival confirmed", subtitle: "Return inspection unlocked") { router.go(to: .toolReturn) }
     VStack(spacing: 16) {
      Image(systemName: "location.circle").font(.system(size: 62)).foregroundStyle(AppTheme.green)
      Text("You're in the return area").font(AppTheme.rounded(23, weight: .heavy)).foregroundStyle(AppTheme.blue)
      Text("Arrival recorded \(flow.reservation?.arrivalAt?.formatted(.dateTime.hour().minute()) ?? "now"), with \(Int(flow.reservation?.arrivalAccuracy ?? 0)) m GPS accuracy, near the designated drop-off.").font(.system(size: 13)).multilineTextAlignment(.center)
     }.padding(24).frame(maxWidth: .infinity).background(AppTheme.green.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 16))
     LoanCard {
      VStack(spacing: 12) {
       BorrowingInfoRow(label: "Area", value: flow.reservation?.pickupAddress ?? "")
       BorrowingInfoRow(label: "Arrival", value: flow.reservation?.arrivalAt?.borrowingDateTime ?? "Recorded")
       BorrowingInfoRow(label: "GPS accuracy", value: "\(Int(flow.reservation?.arrivalAccuracy ?? 0)) meters")
       BorrowingInfoRow(label: "Location stored", value: "Arrival only")
      }
     }
     LoanNotice(icon: "lock.open", title: "Post-rental inspection unlocked",
       message: "Match the same 8 photo angles used at pickup. The owner will review the paired evidence.")
     LoanCard {
      LoanParticipantRow(name: flow.reservation?.ownerName ?? "Owner", detail: "Owner · reviews your return evidence")
     }
    }.padding(18)
   }
   PrimaryButton(title: "Begin return inspection", systemImage: "camera") { router.go(to: .returnCapture) }.padding(18)
  }.background(AppTheme.background)
 }
}

struct CompareConditionView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var lifecycle: LoanLifecycleViewModel
    @State private var selectedFilter = 0
    @State private var enlargedImage: UIImage?
    @State private var showImage = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    LoanHeader(title: "Compare condition", subtitle: "8 photo pairs · zoom to inspect") {
                        router.go(to: .returnCapture)
                    }
                    filterBar
                    ForEach(lifecycle.comparisonResults.filter { selectedFilter == 0 || ($0.verdict == .match ? selectedFilter == 1 : selectedFilter == 2) }) { result in
                        pairCard(result: result)
                    }
                    LoanNotice(
                        icon: "viewfinder.circle",
                        title: lifecycle.comparisonResults.isEmpty
                            ? "Analyzing with Apple Vision..."
                            : "Vision comparison ready",
                        message: "Feature-print distance flags visually different pairs for human review. It never makes the final damage decision."
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

            PrimaryButton(
                title: lifecycle.isLoading ? "Submitting..." : "Submit comparison to owner",
                systemImage: "paperplane",
                enabled: !lifecycle.isLoading && lifecycle.returnPhotos.count == 8
            ) {
                Task {
                    if lifecycle.comparisonResults.isEmpty {
                        guard await lifecycle.analyzeCondition(
                            using: dependencies.conditionComparisonService
                        ) else { return }
                    }
                    guard await lifecycle.syncEvidence(
                        phase: .return,
                        using: dependencies.loanLifecycleRepository
                    ) else { return }
                    guard await lifecycle.syncConditionAnalysis(
                        using: dependencies.loanLifecycleRepository
                    ) else { return }
                    if await lifecycle.move(to: .awaitingReview, using: dependencies.loanLifecycleRepository) {
                        router.go(to: .ownerReview)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
            .background(AppTheme.surface)
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showImage) {
            if let enlargedImage {
                EvidencePhotoDetailView(image: enlargedImage)
            }
        }
        .task {
            if lifecycle.comparisonResults.isEmpty {
                _ = await lifecycle.analyzeCondition(
                    using: dependencies.conditionComparisonService
                )
            }
        }
    }

    private var filterBar: some View {
        let matches = lifecycle.comparisonResults.filter { $0.verdict == .match }.count
        let reviews = lifecycle.comparisonResults.filter { $0.verdict == .review }.count
        return HStack(spacing: 7) {
            Button { selectedFilter = 0 } label: { filter("All \(lifecycle.comparisonResults.count)", selected: selectedFilter == 0) }
            Button { selectedFilter = 1 } label: { filter("\(matches) match", selected: selectedFilter == 1) }
            Button { selectedFilter = 2 } label: { filter("\(reviews) review", selected: selectedFilter == 2) }
        }
    }

    private func filter(_ title: String, selected: Bool) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(selected ? AppTheme.onBlue : AppTheme.green)
            .frame(maxWidth: .infinity)
            .frame(height: 31)
            .background(selected ? AppTheme.blue : AppTheme.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 7).stroke(selected ? AppTheme.blue : AppTheme.border, lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func pairCard(result: ConditionComparisonResult) -> some View {
        let review = result.verdict == .review
        return LoanCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(result.angle.title)
                        .font(AppTheme.rounded(14, weight: .heavy))
                        .foregroundStyle(AppTheme.blue)
                    Spacer()
                    Text(review ? "• Review" : "• Matches")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(review ? AppTheme.coral : AppTheme.green)
                        .padding(.horizontal, 9)
                        .frame(height: 25)
                        .background((review ? AppTheme.coral : AppTheme.green).opacity(0.10))
                }
                HStack(spacing: 8) {
                    pairImage(angle: result.angle, phase: .pickup, label: "BEFORE")
                    pairImage(angle: result.angle, phase: .return, label: "AFTER")
                }
                if review {
                    HStack(alignment: .top, spacing: 9) {
                        Text("1")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.onBlue)
                            .frame(width: 23, height: 23)
                            .background(AppTheme.coral)
                            .clipShape(Circle())
                        Text("Vision distance \(result.distance.formatted(.number.precision(.fractionLength(2)))). This pair is visually different and needs owner review.")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.text)
                    }
                    .padding(10)
                    .background(AppTheme.coral.opacity(0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }
            }
        }
    }

    private func pairImage(angle: EvidenceAngle, phase: EvidencePhase, label: String) -> some View {
        let photo = lifecycle.photos(for: phase).first { $0.angle == angle }
        return ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.blue.opacity(0.10))
            if let photo, let image = lifecycle.image(for: photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(AppTheme.blue)
                .padding(8)
        }
        .frame(height: 100)
        .clipped()
        .onTapGesture { if let photo, let image = lifecycle.image(for: photo) { enlargedImage = image; showImage = true } }
    }
}
