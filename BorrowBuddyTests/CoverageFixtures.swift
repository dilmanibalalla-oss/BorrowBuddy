import CoreLocation
import SwiftUI
import UIKit
import Foundation
@testable import BorrowBuddy

enum CoverageFixtures {
    static func tool(
        id: String = "tool-1",
        ownerID: String = "owner-1",
        name: String = "Cordless Drill",
        category: String = "Power Tools",
        latitude: Double = 43.6532,
        longitude: Double = -79.3832,
        dailyCredits: Int = 8,
        depositCredits: Int = 20,
        isHighValue: Bool = false
    ) -> BorrowingTool {
        BorrowingTool(
            id: id,
            ownerID: ownerID,
            ownerName: "Alex Rivera",
            ownerRating: 4.8,
            ownerLoanCount: 12,
            name: name,
            category: category,
            condition: "Good",
            details: "18V kit",
            dailyCredits: dailyCredits,
            depositCredits: depositCredits,
            latitude: latitude,
            longitude: longitude,
            pickupAddress: "12 Maple Ave",
            imageURL: nil,
            isHighValue: isHighValue,
            estimatedValue: 120,
            photoData: nil,
            listingStatus: "available"
        )
    }

    static func loan(
        id: String = "loan-1",
        ownerID: String = BorrowingTool.demo.ownerID,
        borrowerID: String = "borrower",
        status: ReservationStatus = .active,
        stage: LoanLifecycleStage = .active,
        pickupAt: Date = Date(),
        returnAt: Date = Date().addingTimeInterval(86_400),
        ownerAccepted: Bool = true,
        tool: BorrowingTool = BorrowingTool.demo
    ) -> ReservationRecord {
        ReservationRecord(
            id: id,
            receipt: "LC-1",
            toolID: tool.id,
            toolName: tool.name,
            ownerID: ownerID,
            borrowerID: borrowerID,
            pickupAt: pickupAt,
            returnAt: returnAt,
            totalHold: 30,
            status: status,
            requestedAt: pickupAt,
            ownerAccepted: ownerAccepted,
            lifecycleStage: stage,
            pickupAddress: tool.pickupAddress,
            ownerName: tool.ownerName,
            borrowerName: "Jordan",
            rentalCredits: 16,
            serviceCredits: 2,
            depositCredits: tool.depositCredits,
            toolSnapshot: tool
        )
    }

    static func account(
        name: String = "Jordan",
        balance: Int = 42,
        identityVerified: Bool = false,
        addressConfirmed: Bool = false,
        isPro: Bool = false
    ) -> AccountSummary {
        AccountSummary(
            displayName: name,
            neighborhood: "Maple Grove",
            phoneNumber: "+1 555 0100",
            creditBalance: balance,
            creditHeld: 8,
            streetAddress: "12 Oak Street",
            identityVerified: identityVerified,
            addressConfirmed: addressConfirmed,
            isPro: isPro
        )
    }

    static func uiColor(_ color: Color, style: UIUserInterfaceStyle = .light) -> UIColor {
        UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
    }

    static func contrast(_ foreground: UIColor, on background: UIColor) -> CGFloat {
        let lighter = max(luminance(foreground), luminance(background))
        let darker = min(luminance(foreground), luminance(background))
        return (lighter + 0.05) / (darker + 0.05)
    }

    static func luminance(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func channel(_ value: CGFloat) -> CGFloat {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return (0.2126 * channel(red)) + (0.7152 * channel(green)) + (0.0722 * channel(blue))
    }

    static func renderedSize(width: CGFloat, title: String = "Confirm Location") -> CGSize {
        let content = PrimaryButton(title: title, systemImage: "location.fill") {}
            .frame(width: width)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: width, height: 80)
        return renderer.uiImage?.size ?? .zero
    }
}

final class ScriptedAuthenticationService: AuthenticationService {
    var currentUserID: String? = "user-1"
    var currentDisplayName: String? = "Jordan"
    var onboarded = false
    var signUpError: Error?
    var signInError: Error?
    private(set) var signedInEmail: String?

    func authenticationStateChanges() -> AsyncStream<Bool> {
        let signedIn = currentUserID != nil
        return AsyncStream { continuation in
            continuation.yield(signedIn)
            continuation.finish()
        }
    }

    func signUp(fullName: String, email: String, password: String) async throws {
        if let signUpError { throw signUpError }
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedName.isEmpty, !trimmedEmail.isEmpty, !password.isEmpty else {
            throw AuthenticationError.emptyFields
        }
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            throw AuthenticationError.invalidEmail
        }
        guard password.count >= 6 else {
            throw AuthenticationError.weakPassword
        }
        currentUserID = "user-1"
        currentDisplayName = trimmedName
        signedInEmail = trimmedEmail
    }

    func signIn(email: String, password: String) async throws {
        if let signInError { throw signInError }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            throw AuthenticationError.emptyFields
        }
        currentUserID = "user-1"
        signedInEmail = trimmedEmail
    }

    func signInWithGoogle() async throws {
        if let signInError { throw signInError }
        currentUserID = "user-1"
        currentDisplayName = currentDisplayName ?? "Jordan"
        signedInEmail = "jordan@gmail.com"
    }

    func sendVerificationCode(to phoneNumber: String) async throws -> String {
        guard DevAuthFixtures.isTestPhone(phoneNumber) else {
            throw AuthenticationError.unknown
        }
        return DevAuthFixtures.localVerificationID
    }

    func verify(code: String, verificationID: String?) async throws {
        guard verificationID != nil else { throw AuthenticationError.verificationNotStarted }
        guard code == DevAuthFixtures.testVerificationCode else { throw AuthenticationError.invalidCode }
    }

    func prepareAccount() async throws {
        guard currentUserID != nil else { throw AuthenticationError.signInRequired }
    }

    func completeOnboarding() async throws {
        guard currentUserID != nil else { throw CommunityError.signInRequired }
        onboarded = true
    }

    func hasCompletedOnboarding() async throws -> Bool {
        onboarded
    }

    func signOut() throws {
        currentUserID = nil
        currentDisplayName = nil
        signedInEmail = nil
        onboarded = false
    }
}

final class InMemoryBorrowingRepository: BorrowingRepository {
    var tools: [BorrowingTool] = []
    var loans: [ReservationRecord] = []
    var error: Error?

    func fetchNearbyTools() async throws -> [BorrowingTool] {
        if let error { throw error }
        return tools
    }

    func fetchMyLoans() async throws -> [ReservationRecord] {
        if let error { throw error }
        return loans
    }

    func addTool(_ tool: BorrowingTool) async throws -> String {
        if let error { throw error }
        tools.append(tool)
        return tool.id
    }

    func updateTool(_ tool: BorrowingTool) async throws {
        if let error { throw error }
        guard let index = tools.firstIndex(where: { $0.id == tool.id }) else {
            throw CommunityError.unavailable
        }
        tools[index] = tool
    }

    func deleteTool(id: String) async throws {
        if let error { throw error }
        tools.removeAll { $0.id == id }
    }

    func createReservation(tool: BorrowingTool, quote: ReservationQuote) async throws -> ReservationRecord {
        if let error { throw error }
        let record = CoverageFixtures.loan(
            id: "reservation-\(loans.count + 1)",
            ownerID: tool.ownerID,
            status: .pending,
            stage: .pending,
            pickupAt: quote.pickupAt,
            returnAt: quote.returnAt,
            ownerAccepted: false,
            tool: tool
        )
        loans.append(record)
        return record
    }

    func reservationUpdates(id: String) -> AsyncThrowingStream<ReservationRecord, Error> {
        AsyncThrowingStream { continuation in
            if let error {
                continuation.finish(throwing: error)
                return
            }
            if let loan = loans.first(where: { $0.id == id }) {
                continuation.yield(loan)
            }
            continuation.finish()
        }
    }
}

final class InMemoryAccountRepository: AccountRepository {
    var account: AccountSummary
    var ledger: [WalletEntry] = []
    var events: [ScheduleEvent] = []
    var notifications = NotificationSettings.standard
    var paymentMethod = "StoreKit 2"
    var identitySaved = false
    var error: Error?

    init(account: AccountSummary = CoverageFixtures.account()) {
        self.account = account
    }

    func loadAccount() async throws -> AccountSummary {
        if let error { throw error }
        return account
    }

    func loadLedger() async throws -> [WalletEntry] {
        if let error { throw error }
        return ledger.sorted { $0.recordedAt > $1.recordedAt }
    }

    func loadScheduleEvents() async throws -> [ScheduleEvent] {
        if let error { throw error }
        return events.sorted { $0.occursAt < $1.occursAt }
    }

    func syncScheduleEvents(for loans: [ReservationRecord]) async throws {
        if let error { throw error }
    }

    func clearScheduleActivities(ids: [String]) async throws {
        if let error { throw error }
        events.removeAll { ids.contains($0.id) }
    }

    func updateProfile(displayName: String, neighborhood: String, phoneNumber: String) async throws {
        if let error { throw error }
        account = AccountSummary(
            displayName: displayName,
            neighborhood: neighborhood,
            phoneNumber: phoneNumber,
            creditBalance: account.creditBalance,
            creditHeld: account.creditHeld,
            latitude: account.latitude,
            longitude: account.longitude,
            streetAddress: account.streetAddress,
            unit: account.unit,
            postalCode: account.postalCode,
            identityVerified: account.identityVerified,
            addressConfirmed: account.addressConfirmed,
            isPro: account.isPro
        )
    }

    func updateProfilePhoto(_ data: Data) async throws {
        if let error { throw error }
        account.photoData = data
    }

    func loadNotificationSettings() async throws -> NotificationSettings {
        if let error { throw error }
        return notifications
    }

    func updateNotificationSettings(_ settings: NotificationSettings) async throws {
        if let error { throw error }
        notifications = settings
    }

    func loadPreferredPaymentMethod() async throws -> String {
        if let error { throw error }
        return paymentMethod
    }

    func updatePreferredPaymentMethod(_ method: String) async throws {
        if let error { throw error }
        paymentMethod = method
    }

    func recordStorePurchase(transactionID: String, productID: String, credits: Int, title: String, detail: String) async throws {
        if let error { throw error }
        account = AccountSummary(
            displayName: account.displayName,
            neighborhood: account.neighborhood,
            phoneNumber: account.phoneNumber,
            creditBalance: account.creditBalance + credits,
            creditHeld: account.creditHeld,
            identityVerified: account.identityVerified,
            addressConfirmed: account.addressConfirmed,
            isPro: account.isPro
        )
        ledger.append(WalletEntry(id: transactionID, title: title, detail: detail, credits: credits, recordedAt: Date()))
    }

    func activateProMembership(transactionID: String) async throws {
        if let error { throw error }
        try await setProMembership(active: true)
    }

    func setProMembership(active: Bool) async throws {
        if let error { throw error }
        account = AccountSummary(
            displayName: account.displayName,
            neighborhood: account.neighborhood,
            phoneNumber: account.phoneNumber,
            creditBalance: account.creditBalance,
            creditHeld: account.creditHeld,
            identityVerified: account.identityVerified,
            addressConfirmed: account.addressConfirmed,
            isPro: active
        )
    }

    func syncBorrowingBlock(for loans: [ReservationRecord]) async {}

    func saveIdentityVerification(documentData: Data) async throws {
        if let error { throw error }
        identitySaved = !documentData.isEmpty
        account = AccountSummary(
            displayName: account.displayName,
            neighborhood: account.neighborhood,
            phoneNumber: account.phoneNumber,
            creditBalance: account.creditBalance,
            creditHeld: account.creditHeld,
            identityVerified: identitySaved,
            addressConfirmed: account.addressConfirmed,
            isPro: account.isPro
        )
    }
}
