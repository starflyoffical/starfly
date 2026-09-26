import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct RouteImportView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isCoordinateEditorFocused: Bool
    @State private var coordinateText = ""
    @State private var errorMessage: String?
    @State private var isImportingGPX = false
    @State private var loopCount = 1
    @State private var repeatsIndefinitely = false
    @State private var traversalStyle: RouteTraversalStyle = .continuous
    @State private var waypointHoldSeconds = 3.0
    @State private var sendsRouteNotifications = true

    let onImport: (String, Int, Bool, RouteTraversalStyle, TimeInterval, Bool) -> String?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.black.opacity(0.18), .gray.opacity(0.10), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                    Label("每行一組 緯度, 經度", systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Button {
                        isImportingGPX = true
                    } label: {
                        Label("匯入 GPX", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    TextEditor(text: $coordinateText)
                        .focused($isCoordinateEditorFocused)
                        .font(.body.monospaced())
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(.primary)
                        .padding(12)
                        .frame(minHeight: 220)
                        .starFlyGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .accessibilityLabel("座標路徑")

                    if isCoordinateEditorFocused {
                        Button {
                            isCoordinateEditorFocused = false
                        } label: {
                            Label("收起鍵盤", systemImage: "keyboard.chevron.compact.down")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    Text("25.0330, 121.5654\n25.0334, 121.5661\n25.0340, 121.5668")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("循環", systemImage: "repeat")
                            .font(.subheadline.weight(.semibold))
                        Toggle("無限循環", isOn: $repeatsIndefinitely)
                            .tint(.gray)
                        if !repeatsIndefinitely {
                            Stepper("執行 \(loopCount) 圈", value: $loopCount, in: 1...99)
                        }
                        Text("閉合路線時，最後一點填回起點。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .starFlyGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    traversalSettings

                    if let errorMessage {
                        Label(LocalizedStringKey(errorMessage), systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }

                    Spacer(minLength: 8)
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("建立航線")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("建立路徑") {
                        isCoordinateEditorFocused = false
                        errorMessage = onImport(
                            coordinateText,
                            loopCount,
                            repeatsIndefinitely,
                            traversalStyle,
                            waypointHoldSeconds,
                            sendsRouteNotifications
                        )
                        if errorMessage == nil {
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { isCoordinateEditorFocused = false }
                }
            }
        }
        .fileImporter(
            isPresented: $isImportingGPX,
            allowedContentTypes: [.starFlyGPX],
            allowsMultipleSelection: false,
            onCompletion: importGPX
        )
    }

    private var traversalSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("移動方式", systemImage: "point.3.connected.trianglepath.dotted")
                .font(.subheadline.weight(.semibold))

            Picker("移動方式", selection: $traversalStyle) {
                ForEach(RouteTraversalStyle.allCases) { style in
                    Text(LocalizedStringKey(style.title)).tag(style)
                }
            }
            .pickerStyle(.segmented)

            Text(LocalizedStringKey(traversalStyle.detail))
                .font(.caption)
                .foregroundStyle(.secondary)

            if traversalStyle == .waypointHops {
                HStack {
                    Label("每段步行", systemImage: "figure.walk")
                    Spacer()
                    Text("\(waypointHoldSeconds.formatted(.number.precision(.fractionLength(0)))) 秒")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $waypointHoldSeconds, in: 0...60, step: 1)
                    .tint(.gray)
                Text("0 秒即跳至下一點。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Toggle("顯示路徑通知", isOn: $sendsRouteNotifications)
                .tint(.gray)
        }
        .padding(14)
        .starFlyGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func importGPX(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let canAccess = url.startAccessingSecurityScopedResource()
            defer {
                if canAccess { url.stopAccessingSecurityScopedResource() }
            }

            let points = try GPXRouteCodec.decode(Data(contentsOf: url))
            coordinateText = points.map { point in
                let latitude = String(format: "%.8f", locale: Locale(identifier: "en_US_POSIX"), point.latitude)
                let longitude = String(format: "%.8f", locale: Locale(identifier: "en_US_POSIX"), point.longitude)
                return "\(latitude), \(longitude)"
            }
            .joined(separator: "\n")
            errorMessage = nil
            isCoordinateEditorFocused = false
        } catch let error as CocoaError where error.code == .userCancelled {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
