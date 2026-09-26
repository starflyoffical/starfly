import SwiftUI
import UIKit

struct ConnectionHealthView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var diagnostics = ConnectionDiagnosticsCoordinator()
    @State private var isShowingDeviceSetup = false
    @State private var didCopyDiagnostics = false

    var body: some View {
        List {
            Section("連線狀態") {
                healthRow(
                    title: "Pairing",
                    value: pairingValue,
                    symbol: pairingSymbol,
                    color: pairingColor
                )

                healthRow(
                    title: "LocalDevVPN",
                    value: localDevVPNValue,
                    symbol: localDevVPNSymbol,
                    color: localDevVPNColor
                )

                healthRow(
                    title: "位置工作階段",
                    value: sessionValue,
                    symbol: sessionSymbol,
                    color: sessionColor
                )
            }

            Section("Restoration") {
                Text(appModel.deviceSession.restorationStatus)
                Text("工作階段未啟用表示 StarFly 的背景工作已結束。其他 App 可能需要一些時間才能取得新的實際位置。")
                    .foregroundStyle(.secondary)
            }

            Section("目前位置") {
                LabeledContent("地點", value: activeTarget?.name ?? "無")
                LabeledContent("座標", value: coordinatesValue)

                if let activeTarget, !activeTarget.subtitle.isEmpty {
                    LabeledContent("區域", value: activeTarget.subtitle)
                }
            }

            Section {
                Button {
                    Task { await runConnectionCheck() }
                } label: {
                    HStack {
                        Label("執行連線檢查", systemImage: "stethoscope")
                        Spacer()
                        if diagnostics.state == .running {
                            ProgressView()
                        }
                    }
                }
                .disabled(diagnostics.state == .running)

                if let resultMessage {
                    Label(resultMessage, systemImage: resultSymbol)
                        .font(.subheadline)
                        .foregroundStyle(resultColor)
                }

                if let lastChecked = diagnostics.lastChecked {
                    LabeledContent(
                        "最後檢查",
                        value: lastChecked.formatted(date: .omitted, time: .shortened)
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } header: {
                Text("連線檢查")
            } footer: {
                Text("這會檢查已儲存的配對紀錄，以及已配對的 iPhone 是否能透過 LocalDevVPN 找到。它不會開始、變更或停止你的位置。")
            }

            Section {
                Button {
                    UIPasteboard.general.string = diagnosticsText
                    didCopyDiagnostics = true
                } label: {
                    Label(
                        didCopyDiagnostics ? "診斷資料已複製" : "複製診斷資料",
                        systemImage: didCopyDiagnostics ? "checkmark" : "doc.on.doc"
                    )
                }
                .foregroundStyle(didCopyDiagnostics ? .green : .primary)
            } header: {
                Text("支援")
            } footer: {
                Text("複製僅包含狀態的報告，可貼到錯誤回報中。絕不包含位置、搜尋、配對紀錄、PIN 碼、裝置名稱或錯誤文字。")
            }

            Section("其他 VPN") {
                Text("其他 VPN 可能影響本機裝置連線。如果你的網路環境允許，請暫停該 VPN 後進行比較測試。開始位置工作階段時請保持 LocalDevVPN 啟用。")
                Text("StarFly 未偵測到其他 VPN。這只是疑難排解檢查，不代表診斷結果；iOS 的排程器拒絕可能在配對連線開始前發生。")
                    .foregroundStyle(.secondary)
            }

            Section("說明") {
                Button {
                    isShowingDeviceSetup = true
                } label: {
                    Label("配對與連線", systemImage: "iphone.and.arrow.forward")
                }
                .foregroundStyle(.primary)

                Link(destination: appModel.localDevVPNInstallURL) {
                    Label("在 App Store 開啟 LocalDevVPN", systemImage: "arrow.up.right.square")
                }
            }
        }
        .navigationTitle("連線狀態")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            diagnostics.cancel()
        }
        .sheet(isPresented: $isShowingDeviceSetup) {
            PairingSetupView()
                .environment(appModel)
        }
    }

    private var activeTarget: LocationTarget? {
        if case .active(let target) = appModel.deviceSession.phase {
            return target
        }
        return nil
    }

    private var coordinatesValue: String {
        guard let activeTarget else { return "無" }
        return String(format: "%.5f, %.5f", activeTarget.latitude, activeTarget.longitude)
    }

    private var pairingValue: String {
        switch appModel.pairingStatus {
        case .checking: "檢查中"
        case .importing: "Importing"
        case .notPaired: "尚未配對"
        case .paired: "準備完成"
        case .failed: "有問題"
        }
    }

    private var pairingSymbol: String {
        switch appModel.pairingStatus {
        case .checking, .importing: "arrow.triangle.2.circlepath"
        case .notPaired: "exclamationmark.circle"
        case .paired: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        }
    }

    private var pairingColor: Color {
        switch appModel.pairingStatus {
        case .checking, .importing: .blue
        case .notPaired: .orange
        case .paired: .green
        case .failed: .red
        }
    }

    private var localDevVPNValue: String {
        switch diagnostics.state {
        case .notRun:
            if case .active = appModel.deviceSession.phase { return "已連線" }
            return "尚未檢查"
        case .running: return "檢查中"
        case .passed: return "Reachable"
        case .failed: return "無法連線"
        }
    }

    private var localDevVPNSymbol: String {
        switch diagnostics.state {
        case .notRun:
            if case .active = appModel.deviceSession.phase { return "checkmark.circle.fill" }
            return "questionmark.circle"
        case .running: return "arrow.triangle.2.circlepath"
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    private var localDevVPNColor: Color {
        switch diagnostics.state {
        case .notRun:
            if case .active = appModel.deviceSession.phase { return .green }
            return .secondary
        case .running: return .blue
        case .passed: return .green
        case .failed: return .red
        }
    }

    private var sessionValue: String {
        switch appModel.deviceSession.phase {
        case .idle: "未啟用"
        case .openingLocalDevVPN: "正在開啟 LocalDevVPN"
        case .discovering: "正在尋找此 iPhone"
        case .connecting: "連線中"
        case .active: "啟用中"
        case .stopping: "Stopping"
        case .failed: "失敗"
        }
    }

    private var sessionSymbol: String {
        switch appModel.deviceSession.phase {
        case .idle: "pause.circle"
        case .openingLocalDevVPN, .discovering, .connecting: "arrow.triangle.2.circlepath"
        case .active: "location.circle.fill"
        case .stopping: "stop.circle"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var sessionColor: Color {
        switch appModel.deviceSession.phase {
        case .idle: .secondary
        case .openingLocalDevVPN, .discovering, .connecting, .stopping: .blue
        case .active: .green
        case .failed: .red
        }
    }

    private var resultMessage: String? {
        switch diagnostics.state {
        case .notRun, .running: nil
        case .passed(let message), .failed(let message): message
        }
    }

    private var resultSymbol: String {
        switch diagnostics.state {
        case .passed: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .notRun, .running: "circle"
        }
    }

    private var resultColor: Color {
        switch diagnostics.state {
        case .passed: .green
        case .failed: .red
        case .notRun, .running: .secondary
        }
    }

    private func healthRow(
        title: String,
        value: String,
        symbol: String,
        color: Color
    ) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: symbol)
                        .foregroundStyle(color)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                        Text(value)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: symbol)
                        .foregroundStyle(color)
                        .frame(width: 22)
                    Text(title)
                    Spacer()
                    Text(value)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
    }

    @MainActor
    private func runConnectionCheck() async {
        do {
            let pairingRecord = try await appModel.pairingService.pairingRecordData()
            diagnostics.run(
                pairingRecord: pairingRecord,
                sessionPhase: appModel.deviceSession.phase
            )
        } catch {
            diagnostics.run(pairingRecord: nil, sessionPhase: appModel.deviceSession.phase)
        }
    }

    private var diagnosticsText: String {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "未知"
        let runtimeBundleIdentifier = Bundle.main.bundleIdentifier ?? "未知"
        let permittedBackgroundTasks = (
            Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String]
        )?.joined(separator: ", ") ?? "無"
        let checked = diagnostics.lastChecked?.formatted(date: .numeric, time: .standard) ?? "尚未執行"

        return """
        StarFly Diagnostics
        Generated: \(Date().formatted(date: .numeric, time: .standard))
        App: \(appVersion) (\(build))
        iOS: \(UIDevice.current.systemVersion)
        Runtime bundle identifier: \(runtimeBundleIdentifier)
        Runtime permitted background tasks: \(permittedBackgroundTasks)
        Pairing: \(pairingValue)
        Last pairing failure stage (this launch): \(appModel.onDevicePairing.lastFailureStage?.rawValue ?? "無")
        Pairing scheduler reason (this launch): \(appModel.onDevicePairing.schedulerFailureReason?.rawValue ?? "無")
        Pairing task configuration: \(appModel.onDevicePairing.taskConfigurationStatus.rawValue)
        Pairing task registration: \(appModel.onDevicePairing.taskRegistrationStatus.rawValue)
        LocalDevVPN: \(localDevVPNValue)
        Session: \(sessionValue)
        Last session issue stage (this launch): \(appModel.deviceSession.lastFailureStage?.rawValue ?? "無")
        Last session issue disposition: \(appModel.deviceSession.lastFailureDisposition?.rawValue ?? "無")
        Session scheduler reason (this launch): \(appModel.deviceSession.schedulerFailureReason?.rawValue ?? "無")
        Location task configuration: \(appModel.deviceSession.taskConfigurationStatus.rawValue)
        Location task registration: \(appModel.deviceSession.taskRegistrationStatus.rawValue)
        Location scheduler mode: Registration observation only (no task submitted)
        Background keep-alive: coreLocation
        Background keep-alive status: \(appModel.deviceSession.backgroundKeepAlive.status.rawValue)
        Background keep-alive started: \(appModel.deviceSession.backgroundKeepAlive.started)
        Location BG scheduler available: \(appModel.deviceSession.backgroundTaskSchedulerAvailable)
        Restoration: \(appModel.deviceSession.restorationStatus)
        Last connection check: \(checked)
        Connection check result: \(diagnosticResultStatus)
        Appearance: \(appModel.appearance.title)
        Map style: \(appModel.mapDisplayStyle.title)
        Location data: Not included
        """
    }

    private var diagnosticResultStatus: String {
        switch diagnostics.state {
        case .notRun: "尚未執行"
        case .running: "Running"
        case .passed: "Passed"
        case .failed: "失敗"
        }
    }
}

#Preview {
    NavigationStack {
        ConnectionHealthView()
            .environment(AppModel())
    }
}
