import SwiftUI

struct MessagesInboxView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var threads: [MessageThread] = []
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            LoanHeader(title: "Messages", subtitle: "Notes on your loans") {
                router.go(to: .home)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)

            if isLoading && threads.isEmpty {
                Spacer()
                ProgressView("Loading messages…")
                Spacer()
            } else if threads.isEmpty {
                Spacer()
                ThemeClipart(name: "ClipartChat", height: 180, label: "Neighbors talking on a porch")
                Text(errorMessage == nil ? "No loan messages yet." : "Messages couldn't be loaded. Pull down to retry.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.green)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(threads) { thread in
                            Button {
                                dependencies.apply(thread.loan)
                                router.chatReturnRoute = .messages
                                router.go(to: .loanChat)
                            } label: {
                                threadRow(thread)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(accessibilityText(thread))
                            .accessibilityHint("Opens this conversation.")
                        }
                        AccountSaveStatus(error: errorMessage, success: nil)
                    }
                    .padding(18)
                }
                .refreshable { await load() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .task { await load() }
    }

    private func threadRow(_ thread: MessageThread) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "message.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.blue)
                .frame(width: 36, height: 36)
                .background(AppTheme.blue.opacity(0.08))
                .clipShape(Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(thread.neighborName(currentUserID: dependencies.authenticationService.currentUserID))
                    .font(AppTheme.rounded(15, weight: .bold))
                    .foregroundStyle(AppTheme.blue)
                    .lineLimit(1)
                Text(thread.loan.toolName)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(AppTheme.green)
                    .lineLimit(1)
                Text(thread.latest?.message ?? "No notes yet. Send one from this loan.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border, lineWidth: 1) }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func accessibilityText(_ thread: MessageThread) -> String {
        let name = thread.neighborName(currentUserID: dependencies.authenticationService.currentUserID)
        let preview = thread.latest?.message ?? "No notes yet"
        return "\(name). \(thread.loan.toolName). \(preview)"
    }

    private func load() async {
        if threads.isEmpty { isLoading = true }
        errorMessage = nil
        defer { isLoading = false }
        do {
            let loans = try await dependencies.borrowingRepository.fetchMyLoans()
            var loaded: [MessageThread] = []
            for loan in loans {
                let notes = try? await dependencies.communityRepository.loanNotes(reservationID: loan.id)
                loaded.append(MessageThread(loan: loan, latest: notes?.last))
            }
            threads = loaded.sorted {
                ($0.latest?.createdAt ?? $0.loan.requestedAt) > ($1.latest?.createdAt ?? $1.loan.requestedAt)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct MessageThread: Identifiable {
    let loan: ReservationRecord
    let latest: LoanNote?

    var id: String { loan.id }

    func neighborName(currentUserID: String?) -> String {
        if loan.ownerID == currentUserID {
            return loan.borrowerName.isEmpty ? "Borrower" : loan.borrowerName
        }
        return loan.ownerName.isEmpty ? "Owner" : loan.ownerName
    }
}
