import SwiftUI

enum FriendlyError {
    static let fallback = "Something went wrong. Please try again."

    static func clean(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }

        let lower = trimmed.lowercased()
        if lower.contains("timed out") || lower.contains("timeout") || lower.contains("request timed out") {
            return "That took too long. Check your connection and try again."
        }
        if lower.contains("network") || lower.contains("internet") || lower.contains("offline") || lower.contains("not connected") {
            return "Check your connection and try again."
        }
        if lower.contains("permission denied") || lower.contains("insufficient permissions") || lower.contains("missing or insufficient") {
            return "You don't have permission to do that."
        }
        if lower.contains("simulator") && (lower.contains("location") || lower.contains("gps")) {
            return "Location is off. Turn it on in Settings, or type your address."
        }
        if lower.contains("simulator") && (lower.contains("face id") || lower.contains("biometr")) {
            return "Face ID isn't set up. Turn it on in Settings, then try again."
        }

        let kept = trimmed
            .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !mentionsInternals($0) }
        let sentence = kept.joined(separator: ". ")
        guard !sentence.isEmpty, !looksTechnical(sentence) else { return fallback }
        return sentence.hasSuffix(".") ? sentence : sentence + "."
    }

    private static func mentionsInternals(_ text: String) -> Bool {
        let lower = text.lowercased()
        let words = ["firebase", "firestore", "simulator", "apns", "blaze", "spark plan", "storekit"]
        return words.contains { lower.contains($0) }
    }

    private static func looksTechnical(_ text: String) -> Bool {
        let lower = text.lowercased()
        let markers = [
            "nserror", "error domain", "userinfo", "underlying error",
            "com.google", "com.apple", "grpc", "http status", "code="
        ]
        if markers.contains(where: { lower.contains($0) }) { return true }
        return lower.range(of: #"\berror \d+\b"#, options: .regularExpression) != nil
            || lower.contains("operation couldn't be completed")
            || lower.contains("operation couldn’t be completed")
    }
}

struct DismissingErrorText: View {
    let message: String
    var centered = false
    var topPadding: CGFloat = 0
    var horizontalPadding: CGFloat = 0
    var size: CGFloat = 13

    @State private var isVisible = true

    var body: some View {
        let friendly = FriendlyError.clean(message)
        Group {
            if isVisible {
                Text(friendly)
                    .font(.system(size: size))
                    .foregroundStyle(AppTheme.coral)
                    .multilineTextAlignment(centered ? .center : .leading)
                    .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
                    .padding(.top, topPadding)
                    .padding(.horizontal, horizontalPadding)
                    .accessibilityLabel(friendly)
            }
        }
        .task(id: message) {
            isVisible = true
            try? await Task.sleep(for: .seconds(3))
            isVisible = false
        }
    }
}
