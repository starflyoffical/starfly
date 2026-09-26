import SwiftUI

struct AboutStarFlyView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image("StarFlyBrand")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 23, style: .continuous)
                                .stroke(.white.opacity(0.32), lineWidth: 0.8)
                        }
                    Text("StarFly").font(.title2.bold())
                    Text("你的個人位置與路徑測試工作台。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }

            Section("快速開始") {
                Label("配對此 iPhone 並連線至 LocalDevVPN", systemImage: "iphone.gen3")
                Label("搜尋地點、貼入座標，或直接在地圖放置圖釘", systemImage: "mappin.and.ellipse")
                Label("調整速度與循環設定後開始測試", systemImage: "figure.walk.motion")
            }

            Section("功能") {
                Label("收藏地點與自訂路徑", systemImage: "bookmark.fill")
                Label("支援貼入多組座標建立移動路徑", systemImage: "point.3.connected.trianglepath.dotted")
                Label("使用拉桿或數值輸入控制移動速度", systemImage: "speedometer")
                Label("捷徑完成後自動回到 StarFly", systemImage: "bolt.horizontal.circle.fill")
            }

            Section("安全說明") {
                Text("StarFly 僅供你自己的裝置、App 開發與測試工作流程使用。App 本身不直接改變網路設定；需要時會交由你已建立的 iOS 捷徑執行。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("StarFly 說明")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { AboutStarFlyView() }
}
