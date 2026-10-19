import Foundation
#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

struct TrustedBackendService {
    func checkout(packID: String, requestID: String) async throws -> URL {
        let data = try await call("createCreditCheckout", data: ["packId": packID, "requestId": requestID])
        guard let value = data["url"] as? String, let url = URL(string: value),
              url.scheme == "https", url.host == "checkout.stripe.com" else {
            throw CommunityError.invalidInput("The payment provider did not return a valid secure checkout.")
        }
        return url
    }

    func deleteAccount() async throws { _ = try await call("deleteAccount", data: [:]) }

    private func call(_ name: String, data: [String: Any]) async throws -> [String: Any] {
        #if canImport(FirebaseFunctions)
        guard FirebaseBootstrap.isConfigured else { throw CommunityError.signInRequired }
        do {
            let result = try await Functions.functions(region: "asia-south1").httpsCallable(name).call(data)
            return result.data as? [String: Any] ?? [:]
        } catch {
            let ns = error as NSError
            if ns.code == FunctionsErrorCode.notFound.rawValue || ns.code == FunctionsErrorCode.unavailable.rawValue {
                throw CommunityError.invalidInput("The secure backend has not been deployed or is unavailable. No payment or account deletion was performed.")
            }
            throw error
        }
        #else
        throw CommunityError.invalidInput("The secure backend SDK is not configured. No payment was made.")
        #endif
    }
}
