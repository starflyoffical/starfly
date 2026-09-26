import Foundation
import SwiftUI

struct CoordinateEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @AppStorage("starfly.interfaceLanguage") private var interfaceLanguage = "zh-Hant"

    let onSelect: (LocationTarget) -> Void

    @State private var latitude = ""
    @State private var longitude = ""
    @State private var name = ""
    @State private var errorMessage: String?

    private enum Field: Hashable {
        case latitude
        case longitude
        case name
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(spacing: 14) {
                        coordinateField(
                            title: "緯度",
                            placeholder: "例如 25.033964",
                            value: $latitude,
                            field: .latitude
                        )
                        coordinateField(
                            title: "經度",
                            placeholder: "例如 121.564468",
                            value: $longitude,
                            field: .longitude
                        )

                        VStack(alignment: .leading, spacing: 7) {
                            Text("顯示名稱（選填）")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("精確座標", text: $name)
                                .focused($focusedField, equals: .name)
                                .textInputAutocapitalization(.words)
                                .padding(.horizontal, 14)
                                .frame(height: 50)
                                .starFlyGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .padding(16)
                    .starFlyGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 4)
                    }

                    Button(action: selectCoordinate) {
                        Label("鎖定這個位置", systemImage: "scope")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.black)

                    Text("座標僅用於目前工作階段。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("精確座標")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        focusedField = nil
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                    }
                    .accessibilityLabel("關閉鍵盤")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { focusedField = nil }
                }
            }
            .onAppear { focusedField = .latitude }
        }
    }

    private func coordinateField(
        title: String,
        placeholder: String,
        value: Binding<String>,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(LocalizedStringKey(title))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(LocalizedStringKey(placeholder), text: value)
                .focused($focusedField, equals: field)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body.monospacedDigit())
                .padding(.horizontal, 14)
                .frame(height: 50)
                .starFlyGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onChange(of: value.wrappedValue) { _, pastedValue in
                    guard field == .latitude else { return }
                    separatePastedCoordinatePair(pastedValue)
                }
        }
    }

    private func selectCoordinate() {
        focusedField = nil
        let normalisedLatitude = latitude.replacingOccurrences(of: ",", with: ".")
        let normalisedLongitude = longitude.replacingOccurrences(of: ",", with: ".")
        guard let parsedLatitude = Double(normalisedLatitude),
              let parsedLongitude = Double(normalisedLongitude),
              (-90...90).contains(parsedLatitude),
              (-180...180).contains(parsedLongitude)
        else {
            errorMessage = interfaceLanguage == "en"
                ? "Enter a valid latitude (-90 to 90) and longitude (-180 to 180)."
                : "請輸入有效的緯度（-90 到 90）與經度（-180 到 180）。"
            return
        }

        onSelect(
            LocationTarget(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? (interfaceLanguage == "en" ? "Coordinates" : "精確座標")
                    : name.trimmingCharacters(in: .whitespacesAndNewlines),
                subtitle: interfaceLanguage == "en" ? "Manually entered coordinates" : "手動輸入的經緯度",
                latitude: parsedLatitude,
                longitude: parsedLongitude
            )
        )
        dismiss()
    }

    private func separatePastedCoordinatePair(_ value: String) {
        let values = value
            .components(separatedBy: CharacterSet(charactersIn: ",，\n\t "))
            .filter { !$0.isEmpty }
        guard values.count == 2,
              Double(values[0]) != nil,
              Double(values[1]) != nil
        else { return }

        latitude = values[0]
        longitude = values[1]
        focusedField = nil
    }
}

#Preview {
    CoordinateEntryView { _ in }
}
