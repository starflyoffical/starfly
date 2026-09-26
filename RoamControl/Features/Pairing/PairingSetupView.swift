import SwiftUI
import UniformTypeIdentifiers

struct PairingSetupView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isImporting = false
    @State private var isConfirmingRemoval = false

    private let localDevVPNURL = URL(string: "https://apps.apple.com/app/localdevvpn/id6755608044")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusCard
                    requirementsCard
                    privacyCard
                }
                .padding(16)
            }
            .background {
                LinearGradient(
                    colors: [.black.opacity(0.14), .gray.opacity(0.08), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            .navigationTitle("裝置設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: allowedPairingTypes,
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await appModel.importPairingRecord(from: url) }
        }
        .confirmationDialog(
            "要移除此配對紀錄嗎？",
            isPresented: $isConfirmingRemoval,
            titleVisibility: .visible
        ) {
            Button("移除配對", role: .destructive) {
                Task { await appModel.removePairingRecord() }
            }
        } message: {
            Text("再次連線前，StarFly 需要新的 RPPairing 檔案。")
        }
    }

    private var statusCard: some View {
        setupCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: statusSymbol)
                    .font(.title2)
                    .foregroundStyle(statusColor)
                    .frame(width: 32)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(LocalizedStringKey(statusTitle))
                        .font(.headline)
                    Text(LocalizedStringKey(statusMessage))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(statusTitle). \(statusMessage)")

            if case .paired(let summary) = appModel.pairingStatus {
                Divider()

                pairingDetail(title: "指紋", value: summary.fingerprint, monospaced: true)

                pairingDetail(
                    title: "加入時間",
                    value: summary.importedAt.formatted(date: .abbreviated, time: .shortened)
                )

                Button("替換配對檔案") {
                    isImporting = true
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button("移除配對", role: .destructive) {
                    isConfirmingRemoval = true
                }
                .frame(maxWidth: .infinity)
            } else {
                pairingProgress

                if appModel.onDevicePairing.isAvailableOnThisDevice {
                    if appModel.onDevicePairing.isRunning {
                        Button("取消配對", role: .cancel) {
                            appModel.cancelOnDevicePairing()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    } else {
                        Button {
                            appModel.startOnDevicePairing()
                        } label: {
                            Label("配對此 iPhone", systemImage: "iphone.and.arrow.forward")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isBusy)
                    }
                } else {
                    Label("裝置配對需要你的實體 iPhone。", systemImage: "iphone")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    isImporting = true
                } label: {
                    Label("匯入現有檔案", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isBusy)
            }
        }
    }

    @ViewBuilder
    private var pairingProgress: some View {
        switch appModel.onDevicePairing.phase {
        case .idle, .success, .failed:
            EmptyView()

        case .preparing:
            Divider()
            Label {
                Text("正在準備安全的配對工作階段⋯")
            } icon: {
                ProgressView()
            }
            .font(.subheadline)

        case .waitingForSettings:
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Text("在「設定」中完成")
                    .font(.subheadline.weight(.semibold))
                instructionRow("開啟「設定」›「隱私權與安全性」›「開發者模式」。")
                instructionRow("點選「與 StarFly 配對」。")
                instructionRow("iOS 要求時，輸入這裡顯示的代碼。")
            }

        case .showingPIN(let pin):
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("在「設定」中輸入此代碼")
                    .font(.subheadline.weight(.semibold))
                Text(pin.map(String.init).joined(separator: " "))
                    .font(.largeTitle.weight(.semibold))
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(.blue)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .accessibilityLabel("配對代碼 \(pin)")
                Text("此代碼在這部 iPhone 上產生，並會在本次配對嘗試結束時失效。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .storing:
            Divider()
            Label {
                Text("正在將配對紀錄安全儲存至鑰匙圈⋯")
            } icon: {
                ProgressView()
            }
            .font(.subheadline)

        case .cancelling:
            Divider()
            Label {
                Text("正在停止配對⋯")
            } icon: {
                ProgressView()
            }
            .font(.subheadline)
        }
    }

    private var requirementsCard: some View {
        setupCard {
            Text("連線前")
                .font(.headline)

            requirementRow(number: "1", text: "在此配對這部 iPhone，或匯入既有的 RPPairing 檔案。")
            requirementRow(number: "2", text: "安裝 LocalDevVPN 並將其開啟。")
            requirementRow(number: "3", text: "請在 iPhone 上保持「開發者模式」開啟。")

            Link(destination: localDevVPNURL) {
                Label("查看 LocalDevVPN", systemImage: "arrow.up.right.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Text("iOS 26 支援新的裝置端配對。模擬器可測試畫面，但 Apple 僅在實體 iPhone 提供真正的交握程序。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var privacyCard: some View {
        setupCard {
            Label("已安全儲存", systemImage: "lock.shield")
                .font(.headline)
                .foregroundStyle(.green)

            Text("配對紀錄會在這部 iPhone 上產生或驗證，之後只儲存在其鑰匙圈中；StarFly 不會上傳它。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func setupCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14, content: content)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .starFlyGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func requirementRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.bold())
                .foregroundStyle(.primary)
                .frame(width: 24, height: 24)
                .background(.white.opacity(0.12), in: Circle())

            Text(text)
                .font(.subheadline)
                .padding(.top, 2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("步驟 \(number)：\(text)")
    }

    private func instructionRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.top, 3)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    private func pairingDetail(
        title: String,
        value: String,
        monospaced: Bool = false
    ) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(monospaced ? .caption.monospaced() : .caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LabeledContent(title, value: value)
                    .font(monospaced ? .caption.monospaced() : .caption)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
    }

    private var allowedPairingTypes: [UTType] {
        var types: [UTType] = [.propertyList]
        if let mobileDevicePairing = UTType(filenameExtension: "mobiledevicepairing") {
            types.append(mobileDevicePairing)
        }
        return types
    }

    private var isBusy: Bool {
        appModel.pairingStatus == .checking
            || appModel.pairingStatus == .importing
            || appModel.onDevicePairing.isRunning
    }

    private var statusSymbol: String {
        switch appModel.onDevicePairing.phase {
        case .preparing, .waitingForSettings, .showingPIN, .storing, .cancelling:
            return "iphone.radiowaves.left.and.right"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .idle, .success:
            break
        }

        switch appModel.pairingStatus {
        case .checking, .importing: return "arrow.triangle.2.circlepath"
        case .notPaired: return "iphone.badge.exclamationmark"
        case .paired: return "checkmark.shield.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch appModel.onDevicePairing.phase {
        case .preparing, .waitingForSettings, .showingPIN, .storing, .cancelling:
            return .blue
        case .failed:
            return .red
        case .idle, .success:
            break
        }

        switch appModel.pairingStatus {
        case .checking, .importing: return .blue
        case .notPaired: return .orange
        case .paired: return .green
        case .failed: return .red
        }
    }

    private var statusTitle: String {
        switch appModel.onDevicePairing.phase {
        case .preparing: return "正在準備配對"
        case .waitingForSettings: return "已準備好，請到設定完成"
        case .showingPIN: return "配對代碼已準備好"
        case .storing: return "正在完成配對"
        case .cancelling: return "正在停止配對"
        case .failed: return "配對問題"
        case .idle, .success: break
        }

        switch appModel.pairingStatus {
        case .checking: return "正在檢查此 iPhone"
        case .importing: return "正在檢查配對檔案"
        case .notPaired: return "需要配對"
        case .paired: return "配對檔案已準備好"
        case .failed: return "配對問題"
        }
    }

    private var statusMessage: String {
        switch appModel.onDevicePairing.phase {
        case .preparing:
            return "正在此 iPhone 上開始私人工作階段。"
        case .waitingForSettings:
            return "StarFly 已出現在 iOS 的配對畫面。"
        case .showingPIN:
            return "請在「設定」中輸入六位數代碼以確認。"
        case .storing:
            return "握手成功，正在安全儲存金鑰。"
        case .cancelling:
            return "正在關閉本機工作階段與廣播。"
        case .failed(let message):
            return message
        case .idle, .success:
            break
        }

        switch appModel.pairingStatus {
        case .checking:
            return "正在尋找安全儲存的配對紀錄。"
        case .importing:
            return "正在驗證紀錄與金鑰。"
        case .notPaired:
            return appModel.onDevicePairing.isAvailableOnThisDevice
                ? "在這部 iPhone 上安全建立配對，或匯入既有檔案。"
                : "連接實體 iPhone 以建立配對，或匯入現有檔案。"
        case .paired:
            return "LocalDevVPN 的工作階段層連線後，StarFly 即可使用此紀錄。"
        case .failed(let message):
            return message
        }
    }
}

#Preview {
    PairingSetupView()
        .environment(AppModel())
}
