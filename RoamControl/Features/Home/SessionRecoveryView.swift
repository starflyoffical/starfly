import SwiftUI

struct SessionRecoveryView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let recovery: SessionRecoveryRecord
    let isPaired: Bool
    let isResuming: Bool
    let isRestoring: Bool
    let errorMessage: String?
    let onResume: () -> Void
    let onRestore: () -> Void
    let onAlreadyRestored: () -> Void
    let onCancel: () -> Void

    @State private var isConfirmingRestore = false

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
        .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 20 : 26)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .frame(maxWidth: 520)
        .starFlyGlass(in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .confirmationDialog(
            "要還原此 iPhone 的實際位置嗎？",
            isPresented: $isConfirmingRestore,
            titleVisibility: .visible
        ) {
            Button("還原實際位置", role: .destructive, action: onRestore)
            Button("保留復原選項", role: .cancel) {}
        } message: {
            Text("StarFly 只會重新連線至足以清除模擬位置，不會啟動新的位置或步行工作階段。")
        }
    }

    private var content: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(.secondary.opacity(0.45))
                .frame(width: 38, height: 5)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.black, .gray],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(
                        width: dynamicTypeSize.isAccessibilitySize ? 66 : 78,
                        height: dynamicTypeSize.isAccessibilitySize ? 66 : 78
                    )

                Image(systemName: recovery.isWalkingRoute ? "figure.walk.motion" : "location.fill")
                    .font(.system(size: 31, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 9) {
                Text("上一次工作階段已中斷")
                    .font(.title2.bold())

                Text(summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                recoveryDetail(
                    title: recovery.isWalkingRoute ? "最後儲存的位置" : "最後位置",
                    value: recovery.lastReportedLocation.name,
                    symbol: "mappin.and.ellipse"
                )

                if let destination = recovery.destination, recovery.isWalkingRoute {
                    recoveryDetail(
                        title: "目的地",
                        value: destination.name,
                        symbol: "flag.checkered"
                    )
                }

                recoveryDetail(
                    title: "最後啟用",
                    value: recovery.updatedAt.formatted(date: .abbreviated, time: .shortened),
                    symbol: "clock"
                )
            }
            .padding(14)
            .starFlyGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            if isResuming || isRestoring {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(isRestoring ? "正在還原此 iPhone 的實際位置⋯" : "正在準備路線⋯")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)

                Button("取消還原", role: .cancel, action: onCancel)
                    .foregroundStyle(.secondary)
            } else {
                Button(action: onResume) {
                    Label(resumeTitle, systemImage: recovery.isWalkingRoute ? "figure.walk" : "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isPaired)

                Button(role: .destructive) {
                    isConfirmingRestore = true
                } label: {
                    Label("還原實際位置", systemImage: "location.slash.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!isPaired)

                Button("我的實際位置已經恢復", action: onAlreadyRestored)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !isPaired {
                Label("繼續或還原工作階段前，請先配對此 iPhone。", systemImage: "iphone.and.arrow.forward")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("還原只會重新連線至足以清除模擬位置，不會自動開始其他操作。完成前請保持 StarFly 開啟。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var summaryText: String {
        if let destination = recovery.destination, recovery.isWalkingRoute {
            return "StarFly 關閉前，尚未確認前往 \(destination.name) 的模擬步行是否完成。可從最後儲存的位置繼續，或還原此 iPhone 的實際位置。"
        }

        return "StarFly 關閉前，尚未確認 \(recovery.lastReportedLocation.name) 的模擬位置是否已結束。請選擇此 iPhone 接下來要執行的操作。"
    }

    private var resumeTitle: String {
        recovery.isWalkingRoute ? "繼續步行" : "繼續位置工作階段"
    }

    private func recoveryDetail(title: String, value: String, symbol: String) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: symbol)
                        .foregroundStyle(.primary)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(value)
                            .font(.caption.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 11) {
                    Image(systemName: symbol)
                        .foregroundStyle(.primary)
                        .frame(width: 22)

                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    Text(value)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
    }
}
