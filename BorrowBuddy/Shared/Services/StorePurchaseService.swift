import Combine
import Foundation
import StoreKit

enum StorePurchaseError: LocalizedError, Equatable {
    case cancelled
    case pending
    case unverified
    case unavailable
    case failed

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return nil
        case .pending:
            return "This purchase is pending approval. LendCredits are added after StoreKit confirms it."
        case .unverified:
            return "StoreKit could not verify this transaction on the device."
        case .unavailable:
            return "This product is not available from the App Store yet."
        case .failed:
            return "The App Store could not complete this purchase."
        }
    }
}

@MainActor
final class StorePurchaseService: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro = false

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: StoreCatalog.allProductIDs)
            products = StoreCatalog.allProductIDs.compactMap { id in
                loaded.first { $0.id == id }
            }
        } catch {
            products = []
        }
        await refreshProFlag()
    }

    func product(id: String) -> Product? {
        products.first { $0.id == id }
    }

    func purchase(_ product: Product) async throws -> Transaction {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            return try verified(verification)
        case .userCancelled:
            throw StorePurchaseError.cancelled
        case .pending:
            throw StorePurchaseError.pending
        @unknown default:
            throw StorePurchaseError.failed
        }
    }

    func finish(_ transaction: Transaction) async {
        await transaction.finish()
    }

    /// Applies any verified StoreKit transaction that has not been finished, then syncs Pro.
    func processUnfinishedTransactions(using repository: AccountRepository) async {
        for await result in Transaction.unfinished {
            guard let transaction = try? verified(result) else { continue }
            do {
                try await grant(transaction, using: repository)
                await transaction.finish()
            } catch {
                continue
            }
        }
        await syncMembership(using: repository)
    }

    func grant(_ transaction: Transaction, using repository: AccountRepository) async throws {
        let transactionID = String(transaction.id)
        if transaction.productID == StoreCatalog.proMonthlyProductID {
            try await repository.activateProMembership(transactionID: transactionID)
            isPro = true
            return
        }
        guard let credits = StoreCatalog.credits(for: transaction.productID),
              let pack = StoreCatalog.pack(for: transaction.productID) else {
            return
        }
        try await repository.recordStorePurchase(
            transactionID: transactionID,
            productID: transaction.productID,
            credits: credits,
            title: pack.title,
            detail: "StoreKit 2 purchase"
        )
    }

    private func syncMembership(using repository: AccountRepository) async {
        var verifiedPro: Transaction?
        var sawUnverifiedPro = false
        for await result in Transaction.currentEntitlements {
            let productID: String
            switch result {
            case .verified(let transaction):
                productID = transaction.productID
                if productID == StoreCatalog.proMonthlyProductID {
                    verifiedPro = transaction
                }
            case .unverified(let transaction, _):
                productID = transaction.productID
                if productID == StoreCatalog.proMonthlyProductID {
                    sawUnverifiedPro = true
                }
            }
        }

        if let verifiedPro {
            try? await repository.activateProMembership(transactionID: String(verifiedPro.id))
            isPro = true
        } else if !sawUnverifiedPro {
            try? await repository.setProMembership(active: false)
            isPro = false
        }
    }

    private func refreshProFlag() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == StoreCatalog.proMonthlyProductID {
                active = true
                break
            }
        }
        isPro = active
    }

    private func verified(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified:
            throw StorePurchaseError.unverified
        }
    }
}
