import SwiftUI

struct RestoringRealLocationCard: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
                .tint(.gray)

            Text("位置模擬已停止")
                .font(.headline)

            Text("正在等待此 iPhone 提供新的實際位置。其他 App 也可能需要一些時間才能更新⋯")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .starFlyGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("位置模擬已停止。正在等待此 iPhone 提供新的實際位置。")
    }
}
