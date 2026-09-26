import SwiftUI
import UIKit

struct LocationSelectionCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("starfly.interfaceLanguage") private var interfaceLanguage = "zh-Hant"

    let location: LocationTarget?
    let isFavourite: Bool
    let isPaired: Bool
    let sessionPhase: DeviceSessionPhase
    let localDevVPNInstallURL: URL
    let isPreviewingWalkingRoute: Bool
    let walkingRouteError: String?
    let onToggleFavourite: () -> Void
    let onClearSelection: () -> Void
    let onPreviewWalkingRoute: () -> Void
    let onStart: () -> Void
    let onStop: () -> Void

    @State private var didCopyCoordinates = false
    @State private var isConfirmingStop = false

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.vertical, showsIndicators: false) {
                    cardContent
                }
                .frame(maxHeight: 460)
            } else {
                cardContent
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .starFlyGlass(in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .confirmationDialog(
            "要保留目前的模擬位置嗎？",
            isPresented: $isConfirmingStop,
            titleVisibility: .visible
        ) {
            Button("保留目前位置", role: .cancel) {}
            Button("還原實際位置", role: .destructive, action: onStop)
        } message: {
            Text("保留目前位置不需要任何操作。只有選擇還原時，StarFly 才會停止模擬。")
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(.secondary.opacity(0.34))
                .frame(width: 38, height: 4)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            if let location {
                locationHeader(for: location)

                Button(action: primaryAction) {
                    HStack(spacing: 8) {
                        if isWorking {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: primarySymbol)
                        }
                        Text(LocalizedStringKey(primaryTitle))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(isShowingActiveTarget ? .red : .gray)
                .disabled(isPrimaryDisabled)

                if canPreviewWalkingRoute {
                    Button(action: onPreviewWalkingRoute) {
                        HStack(spacing: 8) {
                            if isPreviewingWalkingRoute {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "figure.walk")
                            }
                            Text(isPreviewingWalkingRoute ? "正在規劃步行路線⋯" : "預覽步行路線")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isPreviewingWalkingRoute)
                }

                if let walkingRouteError {
                    Text(LocalizedStringKey(walkingRouteError))
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if isActive && !isShowingActiveTarget {
                    Button("還原實際位置", role: .destructive) {
                        isConfirmingStop = true
                    }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .frame(maxWidth: .infinity)
                }

                if !statusMessage.isEmpty {
                    Text(LocalizedStringKey(statusMessage))
                        .font(.caption)
                        .foregroundStyle(isFailure ? .red : .secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }

                if shouldOfferLocalDevVPN {
                    Link(destination: localDevVPNInstallURL) {
                        Label("取得 LocalDevVPN", systemImage: "arrow.up.right.square")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "hand.tap")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("搜尋地點或點選地圖")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func locationHeader(for location: LocationTarget) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                locationSummary(for: location)
                HStack(spacing: 4) {
                    Spacer()
                    locationActions
                }
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                locationSummary(for: location)
                Spacer(minLength: 0)
                locationActions
            }
        }
    }

    private func locationSummary(for location: LocationTarget) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.title2)
                .foregroundStyle(.primary)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.headline)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)

                HStack(spacing: 7) {
                    Text(locationDescription(for: location))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)

                    Button {
                        copyLocation(for: location)
                    } label: {
                        Image(systemName: didCopyCoordinates ? "checkmark" : "doc.on.doc")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(StarFlyPressStyle())
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityLabel(didCopyCoordinates ? "位置已複製" : "複製位置")
                }
            }
        }
    }

    @ViewBuilder
    private var locationActions: some View {
        Button(action: onToggleFavourite) {
            Image(systemName: isFavourite ? "heart.fill" : "heart")
                .font(.title3)
                .foregroundStyle(isFavourite ? .primary : .secondary)
                .frame(width: 44, height: 44)
                .symbolEffect(.bounce, value: isFavourite)
        }
        .buttonStyle(StarFlyPressStyle())
        .accessibilityLabel(isFavourite ? "從最愛移除" : "加入最愛")

        if canClearSelection {
            Button(action: onClearSelection) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(StarFlyPressStyle())
            .accessibilityLabel("清除選取的位置")
        }
    }

    private func locationDescription(for location: LocationTarget) -> String {
        let name = location.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle = location.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subtitle.isEmpty else { return name }

        if subtitle.lowercased().hasPrefix(name.lowercased()) {
            let remainder = subtitle.dropFirst(name.count)
                .trimmingCharacters(in: CharacterSet(charactersIn: ", "))
            if !remainder.isEmpty {
                return remainder
            }
        }

        return subtitle
    }

    private func copyLocation(for location: LocationTarget) {
        let name = location.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtitle = location.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)

        if subtitle.isEmpty || subtitle.caseInsensitiveCompare(name) == .orderedSame {
            UIPasteboard.general.string = name
        } else if subtitle.lowercased().hasPrefix(name.lowercased()) {
            UIPasteboard.general.string = subtitle
        } else {
            UIPasteboard.general.string = "\(name), \(subtitle)"
        }
        didCopyCoordinates = true

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            didCopyCoordinates = false
        }
    }

    private var isActive: Bool {
        if case .active = sessionPhase { return true }
        return false
    }

    private var isShowingActiveTarget: Bool {
        guard
            let location,
            case .active(let activeTarget) = sessionPhase
        else { return false }
        return location.id == activeTarget.id
    }

    private var isWorking: Bool {
        switch sessionPhase {
        case .openingLocalDevVPN, .discovering, .connecting, .stopping:
            true
        case .idle, .active, .failed:
            false
        }
    }

    private var isFailure: Bool {
        if case .failed = sessionPhase { return true }
        return false
    }

    private var shouldOfferLocalDevVPN: Bool {
        guard case .failed(let message) = sessionPhase else { return false }
        return message.localizedCaseInsensitiveContains("安裝 LocalDevVPN")
    }

    private var primaryTitle: String {
        switch sessionPhase {
        case .openingLocalDevVPN:
            "正在開啟 LocalDevVPN⋯"
        case .discovering:
            "正在尋找此 iPhone⋯"
        case .connecting:
            "正在開始位置控制⋯"
        case .active:
            isShowingActiveTarget ? "保留目前位置" : "更新位置"
        case .stopping:
            "正在還原實際位置⋯"
        case .failed:
            "再試一次"
        case .idle:
            "開始位置控制"
        }
    }

    private var primarySymbol: String {
        switch sessionPhase {
        case .active: isShowingActiveTarget ? "checkmark.circle.fill" : "location.fill"
        case .failed: "arrow.clockwise"
        case .idle: "location.fill"
        case .openingLocalDevVPN, .discovering, .connecting, .stopping: "hourglass"
        }
    }

    private var isPrimaryDisabled: Bool {
        isWorking || isShowingActiveTarget || (!isPaired && !isActive)
    }

    private var canClearSelection: Bool {
        switch sessionPhase {
        case .idle, .failed:
            true
        case .openingLocalDevVPN, .discovering, .connecting, .active, .stopping:
            false
        }
    }

    private var canPreviewWalkingRoute: Bool {
        switch sessionPhase {
        case .idle, .active:
            true
        case .openingLocalDevVPN, .discovering, .connecting, .stopping, .failed:
            false
        }
    }

    private var statusMessage: String {
        switch sessionPhase {
        case .idle:
            guard location != nil else { return "" }
            if interfaceLanguage == "en" {
                return isPaired ? "The final position will be kept when the route ends." : "Pair this iPhone before starting."
            }
            return isPaired ? "路徑結束後會保留最後位置。" : "開始前請先配對 iPhone。"
        case .openingLocalDevVPN:
            return interfaceLanguage == "en"
                ? "StarFly will return here and continue connecting when LocalDevVPN opens."
                : "LocalDevVPN 啟用後會自動返回並繼續連線。"
        case .discovering:
            return interfaceLanguage == "en" ? "Finding the paired iPhone…" : "正在尋找已配對的 iPhone。"
        case .connecting:
            return interfaceLanguage == "en" ? "Enabling location control…" : "正在啟用位置控制。"
        case .active(let target):
            if !isShowingActiveTarget, let location {
                return interfaceLanguage == "en"
                    ? "Using \(target.name). Updating will move to \(location.name)."
                    : "目前使用 \(target.name)。更新後將移動至 \(location.name)。"
            }
            return interfaceLanguage == "en"
                ? "Location is held at \(target.name). Restore to end the simulation."
                : "目前位置保持在 \(target.name)。選擇還原即可結束。"
        case .stopping:
            return interfaceLanguage == "en"
                ? "Restoring this iPhone’s real location. Keep StarFly open until it finishes."
                : "正在還原此 iPhone 的實際位置。完成前請保持 StarFly 開啟。"
        case .failed(let message):
            return message
        }
    }

    private func primaryAction() {
        if isShowingActiveTarget {
            return
        } else {
            onStart()
        }
    }
}
