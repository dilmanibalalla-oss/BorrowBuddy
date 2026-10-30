//
//  AppDependencies.swift
//  BorrowBuddy
//

import Combine
import CoreLocation
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
    let storePurchases: StorePurchaseService
    let offlineCache: OfflineCacheStore
    let connectivity: ConnectivityMonitor
    let dropOffMonitor: DropOffGeofenceMonitor

    @Published var verificationID: String?
    @Published var verificationPhoneNumber = ""
    @Published var isAuthenticated = false
    /// Latest shed pin, so the tools map can move before the next account read returns.
    @Published var savedShedCoordinate: CLLocationCoordinate2D?
    /// Profile just saved, so the profile screen can show it before the next read returns.
    @Published var editedAccount: AccountSummary?

    private var cancellables: Set<AnyCancellable> = []

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
        self.storePurchases = StorePurchaseService()
        self.offlineCache = OfflineCacheStore()
        self.connectivity = ConnectivityMonitor()
        self.dropOffMonitor = DropOffGeofenceMonitor()
        connectivity.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        connectivity.start()
    }

    func observeAuthentication() {
        Task {
            for await isSignedIn in authenticationService.authenticationStateChanges() {
                isAuthenticated = isSignedIn
                if isSignedIn {
                    await storePurchases.processUnfinishedTransactions(using: accountRepository)
                } else {
                    await notificationService.stopWatchingMessages()
                }
            }
        }
    }

    func syncDropOffRegions(for loans: [ReservationRecord]) {
        dropOffMonitor.sync(loans: loans, borrowerID: authenticationService.currentUserID)
    }

    func handleDropOff(reservationID: String, location: CLLocation?, router: AppRouter) async {
        let busy: Set<AppRoute> = [.returnCapture, .compareCondition, .ownerReview, .loanCompleted, .loanRating]
        guard !busy.contains(router.route) else { return }
        guard let userID = authenticationService.currentUserID,
              var loan = try? await borrowingRepository.fetchReservation(id: reservationID),
              loan.borrowerID == userID,
              loan.status == .active else {
            return
        }

        var confirmed = false
        if let location, loan.lifecycleStage == .active || loan.lifecycleStage == .returnTransit {
            let target = CLLocation(latitude: loan.toolSnapshot.latitude, longitude: loan.toolSnapshot.longitude)
            let distance = location.distance(from: target)
            let age = max(0, Date().timeIntervalSince(location.timestamp))
            confirmed = LoanRules.canVerifyArrival(
                distance: distance,
                accuracy: location.horizontalAccuracy,
                age: age
            )
            if confirmed {
                try? await communityRepository.recordArrival(
                    reservationID: loan.id,
                    accuracy: location.horizontalAccuracy
                )
                if let updated = try? await borrowingRepository.fetchReservation(id: loan.id) {
                    loan = updated
                }
            }
        }

        apply(loan)
        if confirmed {
            router.go(to: .arrivalConfirmed)
            await notificationService.deliver(
                title: "Drop-off area reached",
                body: "You're inside the 50 m return area for \(loan.toolName). The return check is ready."
            )
        } else if loan.lifecycleStage == .active || loan.lifecycleStage == .returnTransit {
            router.go(to: .toolReturn)
            await notificationService.deliver(
                title: "Start the return check",
                body: "You're near the drop-off for \(loan.toolName). Confirm arrival to begin inspection."
            )
        }
    }

}

protocol NotificationService {
    func registerToken() async
    func schedule(for loan: ReservationRecord, preferences: NotificationSettings) async
    func watchLoanMessages(_ loans: [ReservationRecord]) async
    func stopWatchingMessages() async
    func deliver(title: String, body: String) async
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

    func deliver(title: String, body: String) async {
        await loans.deliver(title: title, body: body)
    }
}
