//
//  AppDependencies.swift
//  BorrowBuddy
//

import Combine
import Foundation

@MainActor
final class AppDependencies: ObservableObject {
    let authenticationService: AuthenticationService
    let notificationService: NotificationService
    let userProfileService: UserProfileService
    let accountRepository: AccountRepository
    let borrowingRepository: BorrowingRepository
    let communityRepository: CommunityRepository
    let eventReminderService: EventReminderService
    let borrowingFlow: BorrowingFlowStore
    let loanLifecycle: LoanLifecycleViewModel
    let loanLifecycleRepository: LoanLifecycleRepository
    let conditionComparisonService: ConditionComparisonService

    @Published var verificationID: String?
    @Published var verificationPhoneNumber = ""
    @Published var isAuthenticated = false

    /// Held after email signup so Face ID can store credentials for later unlock.
    var pendingCredentials: StoredCredentials?

    init(
        authenticationService: AuthenticationService = FirebaseAuthenticationService(),
        notificationService: NotificationService = LocalNotificationService(),
        userProfileService: UserProfileService = FirestoreUserProfileService(),
        accountRepository: AccountRepository = FirebaseAccountRepository(),
        borrowingRepository: BorrowingRepository? = nil,
        communityRepository: CommunityRepository? = nil,
        eventReminderService: EventReminderService? = nil,
        borrowingFlow: BorrowingFlowStore? = nil,
        loanLifecycle: LoanLifecycleViewModel? = nil,
        loanLifecycleRepository: LoanLifecycleRepository? = nil,
        conditionComparisonService: ConditionComparisonService? = nil
    ) {
        self.authenticationService = authenticationService
        self.notificationService = notificationService
        self.userProfileService = userProfileService
        self.accountRepository = accountRepository
        self.borrowingRepository = borrowingRepository ?? FirebaseBorrowingRepository()
        self.communityRepository = communityRepository ?? FirebaseCommunityRepository()
        self.eventReminderService = eventReminderService ?? EventReminderService()
        self.borrowingFlow = borrowingFlow ?? BorrowingFlowStore()
        self.loanLifecycle = loanLifecycle ?? LoanLifecycleViewModel()
        self.loanLifecycleRepository = loanLifecycleRepository ?? FirebaseLoanLifecycleRepository()
        self.conditionComparisonService = conditionComparisonService ?? VisionConditionComparisonService()
    }

    func observeAuthentication() {
        Task {
            for await isSignedIn in authenticationService.authenticationStateChanges() {
                isAuthenticated = isSignedIn
                if !isSignedIn {
                    await notificationService.stopWatchingMessages()
                }
            }
        }
    }

}

protocol NotificationService {
    func registerToken() async
    func schedule(for loan: ReservationRecord, preferences: NotificationSettings) async
    func watchLoanMessages(_ loans: [ReservationRecord]) async
    func stopWatchingMessages() async
}

final class LocalNotificationService: NotificationService {
    private let loans = LoanNotificationService()

    func registerToken() async {
        await loans.registerToken()
    }

    func schedule(for loan: ReservationRecord, preferences: NotificationSettings) async {
        await loans.schedule(for: loan, preferences: preferences)
    }

    func watchLoanMessages(_ reservations: [ReservationRecord]) async {
        loans.watchLoanMessages(reservations)
    }

    func stopWatchingMessages() async {
        loans.stopWatchingMessages()
    }
}
