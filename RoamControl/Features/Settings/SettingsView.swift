import ActivityKit
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("starfly.networkShortcutName") private var networkShortcutName = StarFlyShortcut.defaultNetworkWorkflowName
    @AppStorage("starfly.runsNetworkShortcutAutomatically") private var runsNetworkShortcutAutomatically = true
    @AppStorage("starfly.interfaceLanguage") private var interfaceLanguage = "zh-Hant"
    @State private var isShowingDeviceSetup = false
    @State private var isReplayingOnboarding = false
    @State private var isConfirmingReset = false
    @State private var resetError: String?
    @State private var liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.black.opacity(0.16), .gray.opacity(0.10), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        identityCard
                        displaySection
                        liveActivitySection
                        deviceSection
                        healthStepsSection
                        shortcutsSection
                        privacySection
                        starFlySection

                        Button("重設 StarFly", role: .destructive) { isConfirmingReset = true }
                            .font(.subheadline.weight(.semibold))
                            .padding(.vertical, 8)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("控制中心")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $isShowingDeviceSetup) {
            PairingSetupView().environment(appModel)
        }
        .fullScreenCover(isPresented: $isReplayingOnboarding) {
            OnboardingView(isReplay: true).environment(appModel)
        }
        .confirmationDialog("要重設 StarFly 嗎？", isPresented: $isConfirmingReset) {
            Button("重設 App", role: .destructive) { Task { await resetApp() } }
        } message: {
            Text("你的配對紀錄與本機設定將被移除，之後會返回歡迎畫面。")
        }
        .alert("無法完成重設", isPresented: isShowingResetError) {
            Button("好", role: .cancel) { resetError = nil }
        } message: {
            Text(resetError ?? "請再試一次。")
        }
        .onAppear(perform: refreshLiveActivityPermission)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshLiveActivityPermission() }
        }
    }

    private var identityCard: some View {
        HStack(spacing: 14) {
            Image("StarFlyBrand")
                .resizable()
                .scaledToFill()
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(.white.opacity(0.32), lineWidth: 0.8)
                        .allowsHitTesting(false)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text("StarFly").font(.title3.weight(.bold))
            }
            Spacer()
            Text("v\(versionText)")
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .starFlyGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var displaySection: some View {
        StarFlySettingsSection(title: "顯示") {
            VStack(spacing: 16) {
                StarFlySettingsLabel(title: "介面主題", symbol: "circle.lefthalf.filled")
                Picker("介面主題", selection: appearanceBinding) {
                    ForEach(AppAppearance.allCases) { appearance in Text(LocalizedStringKey(appearance.title)).tag(appearance) }
                }
                .pickerStyle(.segmented)

                Divider().opacity(0.45)

                StarFlySettingsLabel(title: "語言", symbol: "globe")
                Picker("語言", selection: $interfaceLanguage) {
                    Text("繁體中文").tag("zh-Hant")
                    Text("English").tag("en")
                }
                .pickerStyle(.segmented)

                Divider().opacity(0.45)

                StarFlySettingsLabel(title: "地圖樣式", symbol: "map")
                Picker("地圖樣式", selection: mapStyleBinding) {
                    ForEach(MapDisplayStyle.allCases) { style in Text(LocalizedStringKey(style.title)).tag(style) }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var deviceSection: some View {
        StarFlySettingsSection(title: "裝置與連線") {
            NavigationLink {
                ConnectionHealthView().environment(appModel)
            } label: {
                StarFlySettingsRow(title: "連線診斷", detail: "查看 LocalDevVPN 與配對狀態", symbol: "wave.3.right.circle.fill", tint: .gray)
            }
            .buttonStyle(StarFlyPressStyle())

            Divider().opacity(0.45)

            Button { isShowingDeviceSetup = true } label: {
                StarFlySettingsRow(title: "配對這部 iPhone", detail: connectionLabel, symbol: "iphone.gen3", tint: .gray)
            }
            .buttonStyle(StarFlyPressStyle())
        }
    }

    private var liveActivitySection: some View {
        StarFlySettingsSection(title: "動態島與即時活動") {
            HStack(spacing: 10) {
                Image(systemName: liveActivitiesEnabled ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(liveActivitiesEnabled ? .green : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("路徑即時狀態").font(.subheadline.weight(.semibold))
                    Text(liveActivitiesEnabled ? "已允許" : "未允許")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("開啟 StarFly 設定") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
            }

            Text("開始路徑後顯示進度。簽署安裝時須保留 StarFlyLiveActivity extension；移除它就不會有動態島。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var shortcutsSection: some View {
        StarFlySettingsSection(title: "捷徑流程") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.primary)
                    TextField("捷徑名稱", text: $networkShortcutName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.subheadline.weight(.medium))
                }
                .padding(12)
                .starFlyGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Toggle("需要時自動執行捷徑", isOn: $runsNetworkShortcutAutomatically)
                    .font(.subheadline.weight(.medium))
                    .tint(.gray)

                HStack(spacing: 10) {
                    Button("建立捷徑") { openURL(StarFlyShortcut.createURL) }
                        .buttonStyle(.bordered)
                    Button("測試關閉流程") { runNetworkShortcut(.turnCellularOff) }
                        .buttonStyle(.borderedProminent)
                        .tint(.gray)
                }

                Text("捷徑接收文字：disable-cellular 時關閉行動數據，其他文字則開啟；完成後返回 StarFly。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var healthStepsSection: some View {
        StarFlySettingsSection(title: "健康資料") {
            NavigationLink {
                HealthStepsView()
            } label: {
                StarFlySettingsRow(
                    title: "健康步數補登",
                    detail: "分段寫入 Apple 健康，標示 StarFly 來源",
                    symbol: "figure.walk",
                    tint: .gray
                )
            }
            .buttonStyle(StarFlyPressStyle())
        }
    }

    private var privacySection: some View {
        StarFlySettingsSection(title: "本機資料") {
            Label {
                Text("收藏、歷史紀錄、路徑與配對資料保存在這部 iPhone。StarFly 不會將這些資料傳送至自家伺服器；地圖搜尋由 Apple 地圖提供。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var starFlySection: some View {
        StarFlySettingsSection(title: "說明") {
            NavigationLink {
                AboutStarFlyView()
            } label: {
                StarFlySettingsRow(title: "使用說明", detail: "位置、路徑與收藏功能", symbol: "sparkles.rectangle.stack.fill", tint: .gray)
            }
            .buttonStyle(StarFlyPressStyle())

            Divider().opacity(0.45)

            Button { isReplayingOnboarding = true } label: {
                StarFlySettingsRow(title: "重新查看開始導覽", detail: "不會清除你的資料", symbol: "arrow.counterclockwise.circle.fill", tint: .gray)
            }
            .buttonStyle(StarFlyPressStyle())
        }
    }

    private var appearanceBinding: Binding<AppAppearance> {
        Binding(get: { appModel.appearance }, set: appModel.setAppearance)
    }

    private var mapStyleBinding: Binding<MapDisplayStyle> {
        Binding(get: { appModel.mapDisplayStyle }, set: appModel.setMapDisplayStyle)
    }

    private var connectionLabel: String {
        switch appModel.connectionState {
        case .notConfigured: "尚未配對"
        case .ready: "準備完成"
        case .connecting: "正在建立連線"
        case .active: "位置控制啟用中"
        case .failed: "需要檢查連線"
        }
    }

    private var versionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0.0"
    }

    private func refreshLiveActivityPermission() {
        liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    }

    private var isShowingResetError: Binding<Bool> {
        Binding(get: { resetError != nil }, set: { if !$0 { resetError = nil } })
    }

    private func runNetworkShortcut(_ command: StarFlyShortcut.NetworkCommand) {
        guard let url = StarFlyShortcut.runURL(named: networkShortcutName, command: command) else { return }
        openURL(url)
    }

    @MainActor
    private func resetApp() async {
        do {
            try await appModel.resetApp()
            dismiss()
        } catch {
            resetError = error.localizedDescription
        }
    }
}

private struct StarFlySettingsSection<Content: View>: View {
    let title: String
    private let content: Content

    init(
        title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey(title)).font(.headline)
            content
        }
        .padding(16)
        .starFlyGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct StarFlySettingsLabel: View {
    let title: String
    let symbol: String

    var body: some View {
        Label(LocalizedStringKey(title), systemImage: symbol)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
    }
}

private struct StarFlySettingsRow: View {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    var showsChevron = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title)).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(LocalizedStringKey(detail)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    SettingsView().environment(AppModel())
}
