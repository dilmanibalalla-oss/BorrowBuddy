import SwiftUI

struct LoanListView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var model = CommunityViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("My loans")
                            .font(AppTheme.rounded(25, weight: .heavy))
                            .foregroundStyle(AppTheme.blue)
                        Spacer()
                        Button("Home") { router.go(to: .home) }
                            .font(AppTheme.rounded(13, weight: .bold))
                            .foregroundStyle(AppTheme.blue)
                    }
                    if model.loans.isEmpty && !model.isLoading {
                        LoanCard {
                            Text(model.sectionErrors["Loan history"] == nil ? "No loans yet" : "Unable to load loans. Pull down to retry.")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.green)
                                .frame(minHeight: 62)
                        }
                    }
                    ForEach(model.loans) { loan in
                        Button {
                            dependencies.open(loan, router: router)
                        } label: {
                            LoanCard {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(loan.toolName)
                                        .font(AppTheme.rounded(16, weight: .bold))
                                        .foregroundStyle(AppTheme.blue)
                                    Text(loan.borrowerID == dependencies.authenticationService.currentUserID
                                         ? "Borrowed from \(loan.ownerName)"
                                         : "Lent to \(loan.borrowerName)")
                                        .font(.system(size: 13))
                                        .foregroundStyle(AppTheme.secondaryText)
                                    Text("\(loan.status.rawValue.capitalized) · due \(loan.returnAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(AppTheme.green)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    AccountSaveStatus(error: model.error, success: nil)
                    if model.isLoading { ProgressView().frame(maxWidth: .infinity) }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
            .refreshable { await model.load(using: dependencies) }
            BorrowingTabBar(
                selectedTab: 0,
                onHome: { router.go(to: .home) },
                onSearch: { router.go(to: .nearbyMap) },
                onCalendar: { router.go(to: .calendar) },
                onProfile: { router.go(to: .profile) }
            )
        }
        .background(AppTheme.background)
        .ignoresSafeArea(.container, edges: .bottom)
        .task { await model.load(using: dependencies) }
    }
}
