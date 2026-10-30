import SwiftUI

struct CompactBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.blue)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

struct StatusPill: View {
    let title: String
    var filled = false

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(filled ? Color(red: 0.66, green: 0.35, blue: 0.05) : AppTheme.blue)
                .frame(width: 6, height: 6)
            Text(title)
                .font(AppTheme.rounded(12, weight: .bold))
        }
        .foregroundStyle(filled ? Color(red: 0.66, green: 0.35, blue: 0.05) : AppTheme.blue)
        .padding(.horizontal, 9)
        .frame(height: 27)
        .background(filled ? Color(red: 1, green: 0.94, blue: 0.83) : AppTheme.surface)
        .overlay {
            if !filled {
                Capsule().stroke(AppTheme.blue, lineWidth: 2)
            }
        }
        .clipShape(Capsule())
    }
}

struct ToolAssetImage: View {
    var imageURL: String?
    var size: CGFloat = 70
    var imageData: Data? = nil
    var fallbackAssetName: String? = nil

    private var imageReference: String? {
        guard let value = imageURL?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }

    private var remoteURL: URL? {
        guard let imageReference, let url = URL(string: imageReference),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              url.host != nil else { return nil }
        return url
    }

    var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image).resizable().scaledToFit()
                    .accessibilityLabel("Photo added by the neighbor")
                    .accessibilityAddTraits(.isImage)
                    .accessibilityRemoveTraits(.isButton)
            } else if remoteURL == nil, let imageReference, let image = UIImage(named: imageReference) {
                Image(uiImage: image).resizable().scaledToFit()
                    .accessibilityAddTraits(.isImage)
                    .accessibilityRemoveTraits(.isButton)
            } else if let remoteURL {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    case .empty:
                        ProgressView().tint(AppTheme.blue)
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var placeholder: some View {
        if let fallbackAssetName {
            Image(fallbackAssetName).resizable().scaledToFit()
                .accessibilityLabel("Tool illustration, not an uploaded listing photo")
        } else {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 28)).foregroundStyle(AppTheme.blue)
                .accessibilityLabel("No tool photo available")
        }
    }
}

struct BorrowingTabBar: View {
    let selectedTab: Int
    let onHome: () -> Void
    let onSearch: () -> Void
    let onCalendar: () -> Void
    let onProfile: () -> Void

    var body: some View {
        HStack {
            tabButton(index: 0, icon: "house", label: "Home", action: onHome)
            Spacer()
            tabButton(index: 1, icon: "magnifyingglass", label: "Search", action: onSearch)
            Spacer()
            tabButton(index: 2, icon: "calendar", label: "Calendar", action: onCalendar)
            Spacer()
            tabButton(index: 3, icon: "person", label: "Profile", action: onProfile)
        }
        .padding(.horizontal, 40)
        .padding(.top, 10)
        .padding(.bottom, 28)
        .background(AppTheme.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(AppTheme.border).frame(height: 1)
        }
    }

    private func tabButton(index: Int, icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(index == selectedTab ? AppTheme.blue : AppTheme.secondaryText)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct BorrowingInfoRow: View {
    let label: String
    let value: String
    var icon: String?
    var valueColor = AppTheme.blue

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.green)
                    .frame(width: 16)
            }
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.green)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(valueColor)
        }
    }
}

extension Date {
    var borrowingDateTime: String {
        formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
    }

    var borrowingShortDate: String {
        formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
}
