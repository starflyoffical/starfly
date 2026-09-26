import SwiftUI

struct StarFlyControlHeader: View {
    let onConnection: () -> Void
    let onCoordinateEntry: () -> Void
    let onHealthSteps: () -> Void
    let onImportRoute: () -> Void
    let onSaved: () -> Void
    let onSettings: () -> Void
    let isRouteLocked: Bool

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onConnection) {
                HStack(spacing: 5) {
                    StarFlyMark()
                    Text("StarFly")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .frame(minHeight: 48)
            }
            .buttonStyle(StarFlyPressStyle())
            .accessibilityLabel("開啟裝置連線")

            Spacer(minLength: 0)

            FlightAction(
                symbol: "location.north.line.fill",
                label: "定位",
                accessibilityLabel: "輸入精確座標",
                action: onCoordinateEntry,
                isDisabled: isRouteLocked
            )
            FlightAction(
                symbol: "figure.walk",
                label: "步數",
                accessibilityLabel: "補登健康步數",
                action: onHealthSteps
            )

            Menu {
                Button(action: onImportRoute) {
                    Label("貼上航線", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .disabled(isRouteLocked)
                Button(action: onSaved) {
                    Label("收藏與紀錄", systemImage: "bookmark.fill")
                }
                Divider()
                Button(action: onSettings) {
                    Label("設定", systemImage: "gearshape")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .starFlyGlass(in: Circle())
            }
            .buttonStyle(StarFlyPressStyle())
            .accessibilityLabel("更多功能")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .starFlyGlass(in: Capsule())
    }
}

private struct StarFlyMark: View {
    var body: some View {
        Image("StarFlyBrand")
            .resizable()
            .scaledToFill()
            .frame(width: 27, height: 27)
            .clipShape(Circle())
            .overlay { Circle().stroke(.white.opacity(0.44), lineWidth: 0.8) }
    }
}

private struct FlightAction: View {
    let symbol: String
    let label: String
    let accessibilityLabel: String
    let action: () -> Void
    var isDisabled = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                Text(LocalizedStringKey(label))
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .frame(minHeight: 48)
            .starFlyGlass(in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(StarFlyPressStyle())
        .disabled(isDisabled)
        .accessibilityLabel(Text(LocalizedStringKey(accessibilityLabel)))
        .accessibilityAddTraits(.isButton)
    }
}
