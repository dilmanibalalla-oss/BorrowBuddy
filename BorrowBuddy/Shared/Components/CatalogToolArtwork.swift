import SwiftUI

// Original design assets are illustrations, never fabricated uploaded evidence.
struct CatalogToolArtwork: View {
    let tool: BorrowingTool
    var body: some View {
        GeometryReader { geometry in
            ToolAssetImage(imageURL: tool.imageURL,
                           size: min(geometry.size.width, geometry.size.height),
                           imageData: tool.photoData,
                           fallbackAssetName: illustrationAssetName)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var illustrationAssetName: String? {
        if tool.name.localizedCaseInsensitiveContains("drill") { return "DrillTool" }
        if tool.name.localizedCaseInsensitiveContains("ladder") { return "LadderTool" }
        return nil
    }
}
