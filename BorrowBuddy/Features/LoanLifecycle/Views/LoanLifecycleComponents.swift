import MapKit
import SwiftUI
import UIKit

struct LoanHeader: View {
    let title: String
    let subtitle: String
    let backAction: () -> Void
    var trailingTitle: String?

    init(
        title: String,
        subtitle: String,
        trailingTitle: String? = nil,
        backAction: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailingTitle = trailingTitle
        self.backAction = backAction
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            CompactBackButton(action: backAction)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.rounded(22, weight: .heavy))
                    .foregroundStyle(AppTheme.blue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.green)
            }
            Spacer()
            if let trailingTitle {
                Text(trailingTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.blue)
                    .padding(.top, 8)
            }
        }
    }
}

struct LoanProgressBar: View {
    let active: Int

    var body: some View {
        HStack(spacing: 7) {
            step("Pending", index: 0)
            line(index: 0)
            step("Active", index: 1)
            line(index: 1)
            step("Completed", index: 2)
        }
    }

    private func step(_ title: String, index: Int) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(index <= active ? AppTheme.blue : AppTheme.border)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 10.5, weight: index == active ? .bold : .regular))
                .foregroundStyle(index <= active ? AppTheme.blue : AppTheme.secondaryText)
        }
    }

    private func line(index: Int) -> some View {
        Rectangle()
            .fill(index < active ? AppTheme.blue : AppTheme.border)
            .frame(height: 1.5)
    }
}

struct LoanCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppTheme.border, lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct LoanNotice: View {
    let icon: String
    let title: String
    let message: String
    var color = AppTheme.green
    var background = AppTheme.green.opacity(0.08)

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(color)
                Text(message)
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.text)
                    .lineSpacing(3)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct EvidenceThumbnail: View {
    let title: String
    let image: UIImage?
    var tint = AppTheme.blue

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(tint)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            VStack {
                HStack {
                    Image(systemName: image == nil ? "photo" : "checkmark.circle.fill")
                        .foregroundStyle(image == nil ? AppTheme.onBlue : AppTheme.yellow)
                    Spacer()
                }
                Spacer()
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(image == nil ? AppTheme.onBlue : Color.white)
            }
            .padding(8)
        }
        .frame(height: 91)
        .clipped()
    }
}

struct PickupMapCard: View {
    let coordinate: CLLocationCoordinate2D
    let label: String
    var radiusVisible = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Map(initialPosition: .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)
                )
            )) {
                Marker(label, coordinate: coordinate)
                    .tint(AppTheme.blue)
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .allowsHitTesting(false)

            if radiusVisible {
                Circle()
                    .fill(AppTheme.blue.opacity(0.08))
                    .frame(width: 132, height: 132)
                    .overlay {
                        Circle()
                            .stroke(AppTheme.blue, style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.blue)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }
}

struct EvidenceImagePicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage) -> Void

        init(onImage: @escaping (UIImage) -> Void) {
            self.onImage = onImage
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
