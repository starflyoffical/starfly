import SwiftUI

@MainActor
struct HealthStepsView: View {
    private enum InputField: Hashable {
        case stepCount
        case sampleCount
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("starfly.interfaceLanguage") private var interfaceLanguage = "zh-Hant"
    @FocusState private var focusedField: InputField?
    @State private var stepWriter = HealthStepWriter()
    @State private var stepCountInput = "1200"
    @State private var sampleCountInput = ""
    @State private var usesCustomSampleCount = false
    @State private var isConfirmingWrite = false
    @State private var isWriting = false
    @State private var resultMessage: String?
    @State private var errorMessage: String?

    private let stepIncrementPresets = [100, 500, 1_000, 5_000, 10_000]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                informationCard
                inputCard

                if let resultMessage {
                    Label(resultMessage, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .starFlyGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Button {
                    focusedField = nil
                    isConfirmingWrite = true
                } label: {
                    HStack(spacing: 9) {
                        if isWriting { ProgressView().tint(.white) }
                        Text(isWriting
                            ? localized("正在寫入…", "Writing…")
                            : localized("寫入 Apple 健康", "Write to Apple Health"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isWriting || stepCount == 0)
            }
            .padding(16)
            .animation(reduceMotion ? nil : .smooth(duration: 0.26), value: resultMessage)
            .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: usesCustomSampleCount)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .background {
            LinearGradient(
                colors: [.black.opacity(0.16), .gray.opacity(0.10), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .navigationTitle(localized("健康步數補登", "Health Steps"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(localized("完成", "Done")) { dismiss() }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(localized("收起鍵盤", "Done")) { focusedField = nil }
                    .font(.body.weight(.semibold))
            }
        }
        .confirmationDialog(
            localized("確認補登步數", "Confirm step entry"),
            isPresented: $isConfirmingWrite,
            titleVisibility: .visible
        ) {
            Button(localized("寫入 \(stepCount.formatted()) 步", "Write \(stepCount.formatted()) steps")) {
                Task { await writeSteps() }
            }
            Button(localized("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(localized(
                "會以現在為結束時間，分成 \(distributionSampleCount) 筆寫入。",
                "Steps will be split into \(distributionSampleCount) samples ending now."
            ))
        }
        .alert(
            localized("步數寫入失敗", "Couldn’t write steps"),
            isPresented: isShowingError
        ) {
            Button(localized("好", "OK"), role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? localized("請稍後再試。", "Please try again later."))
        }
        .onChange(of: usesCustomSampleCount) { _, isCustom in
            if isCustom, sampleCountInput.isEmpty {
                sampleCountInput = "\(recommendedSampleCount)"
            } else if !isCustom {
                focusedField = nil
            }
        }
        .onChange(of: maximumSampleCount) { _, maximum in
            guard usesCustomSampleCount,
                  let currentCount = Int(sampleCountInput),
                  currentCount > maximum
            else { return }
            sampleCountInput = "\(maximum)"
        }
    }

    private var informationCard: some View {
        Label(
            localized(
                "以現在為結束時間，步數會分批補登。",
                "Entries end now and are split into smaller samples."
            ),
            systemImage: "clock.arrow.circlepath"
        )
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .starFlyGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label(localized("補登步數", "Step count"), systemImage: "figure.walk")
                .font(.headline)

            HStack(spacing: 5) {
                Text(localized("步數", "Steps"))
                Spacer(minLength: 0)
                Button {
                    focusedField = nil
                    stepCountInput = "\(max(1, stepCount - 50))"
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .frame(width: 42, height: 44)
                }
                .buttonStyle(StarFlyPressStyle())
                .accessibilityLabel(localized("減少 50 步", "Decrease by 50 steps"))

                TextField(localized("步數", "Steps"), text: $stepCountInput)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .stepCount)
                    .multilineTextAlignment(.center)
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .frame(width: 82, height: 44)
                    .background(.white.opacity(0.12), in: Capsule())
                    .accessibilityLabel(localized("步數", "Steps"))
                    .onChange(of: stepCountInput) { _, value in
                        let digits = String(value.filter(\.isNumber).prefix(5))
                        let clamped = min(Int(digits) ?? 0, 10_000)
                        let replacement = digits.isEmpty ? "" : "\(clamped)"
                        if replacement != value { stepCountInput = replacement }
                    }

                Text(localized("步", "steps"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    focusedField = nil
                    stepCountInput = "\(min(10_000, stepCount + 50))"
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .frame(width: 42, height: 44)
                }
                .buttonStyle(StarFlyPressStyle())
                .accessibilityLabel(localized("增加 50 步", "Increase by 50 steps"))
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(stepIncrementPresets, id: \.self) { increment in
                    Button {
                        focusedField = nil
                        stepCountInput = "\(min(10_000, stepCount + increment))"
                    } label: {
                        Text("+\(increment.formatted())")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 39)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(StarFlyPressStyle())
                    .starFlyGlass(in: Capsule())
                    .disabled(stepCount >= 10_000 || isWriting)
                }
            }

            Divider().overlay(.white.opacity(0.12))

            HStack(spacing: 10) {
                Label(localized("分配次數", "Samples"), systemImage: "waveform.path")
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: 0)
                Picker(localized("分配次數", "Samples"), selection: $usesCustomSampleCount) {
                    Text(localized("自動", "Auto")).tag(false)
                    Text(localized("自訂", "Custom")).tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 132)
            }

            if usesCustomSampleCount {
                HStack(spacing: 10) {
                    Button {
                        setCustomSampleCount(distributionSampleCount - 1)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(StarFlyPressStyle())
                    .disabled(distributionSampleCount <= 1)

                    TextField("\(recommendedSampleCount)", text: $sampleCountInput)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .sampleCount)
                        .multilineTextAlignment(.center)
                        .font(.body.monospacedDigit().weight(.semibold))
                        .frame(width: 78, height: 42)
                        .background(.white.opacity(0.12), in: Capsule())
                        .accessibilityLabel(localized("分配筆數", "Sample count"))
                        .onChange(of: sampleCountInput) { _, value in updateSampleCountInput(value) }

                    Text(localized("筆", "samples"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        setCustomSampleCount(distributionSampleCount + 1)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(StarFlyPressStyle())
                    .disabled(distributionSampleCount >= maximumSampleCount)
                    Spacer(minLength: 0)
                }
            }

            Label(distributionSummary, systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .starFlyGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .disabled(isWriting)
    }

    private var stepCount: Int {
        min(max(Int(stepCountInput) ?? 0, 0), 10_000)
    }

    private var automaticStartDate: Date {
        HealthStepWriter.automaticStartDate(for: max(1, stepCount))
    }

    private var recommendedSampleCount: Int {
        HealthStepWriter.estimatedSampleCount(for: max(1, stepCount), startingAt: automaticStartDate)
    }

    private var maximumSampleCount: Int {
        HealthStepWriter.maximumAllowedSampleCount(for: max(1, stepCount), startingAt: automaticStartDate)
    }

    private var distributionSampleCount: Int {
        guard usesCustomSampleCount,
              let customCount = Int(sampleCountInput),
              !sampleCountInput.isEmpty
        else { return recommendedSampleCount }
        return min(max(customCount, 1), maximumSampleCount)
    }

    private var distributionSummary: String {
        if usesCustomSampleCount {
            return localized(
                "自訂 \(distributionSampleCount) 筆 · 上限 \(maximumSampleCount) 筆",
                "Custom · \(distributionSampleCount) of \(maximumSampleCount) samples"
            )
        }
        return localized("自動分成 \(distributionSampleCount) 筆", "Auto · \(distributionSampleCount) samples")
    }

    private var isShowingError: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func setCustomSampleCount(_ count: Int) {
        usesCustomSampleCount = true
        sampleCountInput = "\(min(max(count, 1), maximumSampleCount))"
        focusedField = nil
    }

    private func updateSampleCountInput(_ value: String) {
        let digits = String(value.filter(\.isNumber).prefix(3))
        guard !digits.isEmpty else {
            if !value.isEmpty { sampleCountInput = "" }
            return
        }
        let clamped = min(max(Int(digits) ?? 1, 1), maximumSampleCount)
        if "\(clamped)" != value { sampleCountInput = "\(clamped)" }
    }

    private func writeSteps() async {
        isWriting = true
        resultMessage = nil
        defer { isWriting = false }

        do {
            let sampleCount = try await stepWriter.addSteps(
                stepCount,
                sampleCount: distributionSampleCount
            )
            resultMessage = localized(
                "已將步數分成 \(sampleCount) 筆寫入 Apple 健康。",
                "Added steps to Apple Health in \(sampleCount) samples."
            )
        } catch {
            errorMessage = (error as? HealthStepWriteError)?.message(for: interfaceLanguage)
                ?? error.localizedDescription
        }
    }

    private func localized(_ chinese: String, _ english: String) -> String {
        interfaceLanguage == "en" ? english : chinese
    }
}

#Preview {
    NavigationStack { HealthStepsView() }
}
