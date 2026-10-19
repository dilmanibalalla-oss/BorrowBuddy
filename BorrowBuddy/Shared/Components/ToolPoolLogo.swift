import SwiftUI

struct ToolPoolLogo: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(AppTheme.shadow)
                .frame(width: 140, height: 140)
                .offset(y: 7)

            RoundedRectangle(cornerRadius: 22)
                .fill(AppTheme.yellow)
                .frame(width: 140, height: 140)
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(AppTheme.blue, lineWidth: 4)
                }

            Rectangle()
                .fill(AppTheme.blue)
                .frame(width: 136, height: 17)

            Image(systemName: "wrench.adjustable")
                .font(.system(size: 41, weight: .medium))
                .foregroundStyle(AppTheme.blue)
                .offset(x: 9, y: -19)

            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.blue, lineWidth: 4)
                .frame(width: 56, height: 22)
                .offset(x: -42, y: -80)
        }
        .frame(width: 165, height: 172)
        .accessibilityHidden(true)
    }
}
