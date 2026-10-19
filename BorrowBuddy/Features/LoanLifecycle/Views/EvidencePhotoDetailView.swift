import SwiftUI

struct EvidencePhotoDetailView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @GestureState private var gestureScale: CGFloat = 1
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    Image(uiImage: image).resizable().scaledToFit()
                        .frame(width: geometry.size.width * min(6, max(1, scale * gestureScale)),
                               height: geometry.size.height * min(6, max(1, scale * gestureScale)))
                        .gesture(MagnificationGesture().updating($gestureScale) { value, state, _ in state = value }
                            .onEnded { scale = min(6, max(1, scale * $0)) })
                        .onTapGesture(count: 2) { scale = scale == 1 ? 2 : 1 }
                }
            }.navigationTitle("Condition evidence").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() } }
        }
    }
}
