import SwiftUI

struct MobileDataGuidanceView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("starfly.runsNetworkShortcutAutomatically") private var runsNetworkShortcutAutomatically = true

    let guidance: MobileDataGuidance
    let onOpenLocalDevVPN: () -> Void
    let onRetry: () -> Void
    let onUseMobileData: () -> Void
    let onMobileDataOff: () -> Void
    let onRunNetworkShortcut: (StarFlyShortcut.NetworkCommand) -> Void
    let onCancel: () -> Void
    let onDone: () -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.vertical, showsIndicators: false) {
                    content
                }
                .frame(maxHeight: 540)
            } else {
                content
            }
        }
        .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 20 : 28)
        .padding(.top, 12)
        .padding(.bottom, 26)
        .frame(maxWidth: 520)
        .starFlyGlass(in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .onChange(of: guidance, initial: true) { _, newGuidance in
            guard runsNetworkShortcutAutomatically else { return }
            switch newGuidance {
            case .turnOff:
                onRunNetworkShortcut(.turnCellularOff)
            case .turnBackOn:
                onRunNetworkShortcut(.turnCellularOn)
            case .connectionHelp:
                break
            }
        }
    }

    private var content: some View {
        VStack(spacing: 22) {
            Capsule()
                .fill(.secondary.opacity(0.45))
                .frame(width: 38, height: 5)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: iconColours,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(
                        width: dynamicTypeSize.isAccessibilitySize ? 68 : 82,
                        height: dynamicTypeSize.isAccessibilitySize ? 68 : 82
                    )

                Image(systemName: iconSymbol)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 10) {
                Text(LocalizedStringKey(title))
                    .font(.title2.bold())

                Text(LocalizedStringKey(message))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if guidance == .connectionHelp {
                Label(
                    "StarFly 尚未找到 LocalDevVPN 的裝置連線。",
                    systemImage: "lock.shield"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

                Button("再試一次", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                Button("開啟 LocalDevVPN", action: onOpenLocalDevVPN)
                    .buttonStyle(.bordered)

                Button("我正在使用行動數據", action: onUseMobileData)
                    .buttonStyle(.bordered)

                Button("取消", role: .cancel, action: onCancel)
                    .foregroundStyle(.secondary)
            } else if guidance == .turnOff {
                HStack(spacing: 9) {
                    ProgressView()
                    Text("正在偵測此 iPhone⋯")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .starFlyGlass(in: Capsule())

                Label(
                    "StarFly 應會自動繼續；若沒有，請點選「繼續」。",
                    systemImage: "checkmark.seal.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

                Button("繼續", action: onMobileDataOff)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                Button("開啟 LocalDevVPN", action: onOpenLocalDevVPN)
                    .buttonStyle(.bordered)

                Button("執行關閉數據捷徑") {
                    onRunNetworkShortcut(.turnCellularOff)
                }
                    .buttonStyle(.bordered)

                Button("取消", role: .cancel, action: onCancel)
                    .foregroundStyle(.secondary)

                Text("StarFly 已將「關閉行動數據」指令傳給捷徑。完成後會自動回到 App 並繼續連線。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Label("位置控制已啟用", systemImage: "location.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Button("執行開啟數據捷徑") {
                    onRunNetworkShortcut(.turnCellularOn)
                }
                    .buttonStyle(.bordered)

                Button("完成", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var title: String {
        switch guidance {
        case .connectionHelp:
            "仍在連線"
        case .turnOff:
            "關閉行動數據"
        case .turnBackOn:
            "重新開啟行動數據"
        }
    }

    private var message: String {
        switch guidance {
        case .connectionHelp:
            "若使用 Wi‑Fi，請確認 LocalDevVPN 顯示已連線後再試一次。只有實際使用 4G 或 5G 時才選擇行動數據。"
        case .turnOff:
            "請確認 LocalDevVPN 已連線，暫時關閉行動數據後再回到 StarFly。"
        case .turnBackOn:
            "安全的位置工作階段已準備好。現在可以重新開啟行動數據，位置模擬會持續透過 5G 運作。"
        }
    }

    private var iconColours: [Color] {
        switch guidance {
        case .connectionHelp: [.black, .gray]
        case .turnOff: [.black, .gray]
        case .turnBackOn: [.gray, .white]
        }
    }

    private var iconSymbol: String {
        switch guidance {
        case .connectionHelp: "lock.shield.fill"
        case .turnOff: "antenna.radiowaves.left.and.right"
        case .turnBackOn: "checkmark"
        }
    }
}
