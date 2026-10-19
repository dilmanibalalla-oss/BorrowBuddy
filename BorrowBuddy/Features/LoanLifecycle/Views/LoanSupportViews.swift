import SwiftUI

struct LoanChatView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var flow: BorrowingFlowStore
    @State private var notes: [LoanNote] = []
    @State private var draft = ""
    @State private var errorMessage: String?
    @State private var isSending = false

    private var loan: ReservationRecord? { flow.reservation }
    private var neighborName: String {
        guard let loan else { return "Neighbor" }
        return loan.ownerID == dependencies.authenticationService.currentUserID ? loan.borrowerName : loan.ownerName
    }

    var body: some View {
        VStack(spacing: 0) {
            LoanHeader(title: neighborName, subtitle: loan?.toolName ?? "Loan note") {
                router.go(to: .reservationPending)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if notes.isEmpty {
                        Text("No notes yet. Send a short note about pickup or return.")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.green)
                    }
                    ForEach(notes) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.authorID == dependencies.authenticationService.currentUserID ? "You" : neighborName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppTheme.blue)
                            Text(note.message)
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.text)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    AccountSaveStatus(error: errorMessage, success: nil)
                }
                .padding(18)
            }
            HStack(spacing: 10) {
                TextField("Write a note", text: $draft)
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(Color.white)
                    .overlay { RoundedRectangle(cornerRadius: 11).stroke(AppTheme.border) }
                Button(isSending ? "..." : "Send") { Task { await send() } }
                    .font(AppTheme.rounded(14, weight: .bold))
                    .foregroundStyle(AppTheme.blue)
                    .disabled(isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(18)
        }
        .background(AppTheme.background)
        .task(id: loan?.id) { await reload() }
    }

    private func reload() async {
        guard let id = loan?.id else { return }
        do {
            notes = try await dependencies.communityRepository.loanNotes(reservationID: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func send() async {
        guard let id = loan?.id, !isSending else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            try await dependencies.communityRepository.postLoanNote(reservationID: id, message: draft)
            draft = ""
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct LoanRatingView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var flow: BorrowingFlowStore
    @State private var stars = 5
    @State private var comment = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LoanHeader(title: "Rate your neighbor", subtitle: flow.reservation?.toolName ?? "Completed loan") {
                router.go(to: .loanCompleted)
            }
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { value in
                    Button { stars = value } label: {
                        Image(systemName: value <= stars ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundStyle(AppTheme.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            TextField("Optional comment", text: $comment, axis: .vertical)
                .lineLimit(3...6)
                .padding(12)
                .background(Color.white)
                .overlay { RoundedRectangle(cornerRadius: 11).stroke(AppTheme.border) }
            AccountSaveStatus(error: errorMessage, success: nil)
            PrimaryButton(title: isSaving ? "Saving..." : "Submit rating", enabled: !isSaving) {
                Task { await submit() }
            }
            Spacer()
        }
        .padding(18)
        .background(AppTheme.background)
    }

    private func submit() async {
        guard let id = flow.reservation?.id else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await dependencies.communityRepository.submitRating(
                reservationID: id,
                rating: LoanRating(stars: stars, comment: comment.trimmingCharacters(in: .whitespacesAndNewlines))
            )
            router.go(to: .loanCompleted)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct HelpSupportView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LoanHeader(title: "Help & Support", subtitle: "Loan issues stay private") {
                router.go(to: loanBack)
            }
            LoanNotice(
                icon: "lock",
                title: "Report a private issue",
                message: "If a tool comes back damaged or a neighbor misses the return, pause settlement from the review screen or open a non-return case from loan help."
            )
            LoanOutlineButton(title: "Back to my loans") { router.go(to: .loanList) }
            Spacer()
        }
        .padding(18)
        .background(AppTheme.background)
    }

    private var loanBack: AppRoute {
        .loanCompleted
    }
}

struct NonReturnCaseView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var flow: BorrowingFlowStore
    @State private var reason = ""
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LoanHeader(title: "Non-return case", subtitle: flow.reservation?.toolName ?? "Overdue loan") {
                router.go(to: .activeLoan)
            }
            Text("Tell us what happened. Opening a case records the overdue loan for follow-up.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.text)
            TextField("What happened?", text: $reason, axis: .vertical)
                .lineLimit(4...8)
                .padding(12)
                .background(Color.white)
                .overlay { RoundedRectangle(cornerRadius: 11).stroke(AppTheme.border) }
            AccountSaveStatus(error: errorMessage, success: successMessage)
            PrimaryButton(title: isSaving ? "Opening..." : "Open case", enabled: !isSaving && !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                Task { await openCase() }
            }
            Spacer()
        }
        .padding(18)
        .background(AppTheme.background)
    }

    private func openCase() async {
        guard let loan = flow.reservation, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let id = try await FirebaseNonReturnCaseRepository().openCase(
                reservationID: loan.id,
                toolID: loan.toolID,
                borrowerID: loan.borrowerID,
                reason: reason.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            successMessage = "Case \(id) is open."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
