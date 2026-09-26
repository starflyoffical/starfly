import MapKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct WalkingRoutePreviewCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("starfly.interfaceLanguage") private var interfaceLanguage = "zh-Hant"
    @FocusState private var isSpeedInputFocused: Bool
    @State private var panelHeight: CGFloat = 410
    @State private var isExportingGPX = false
    @State private var gpxExportDocument = GPXRouteDocument(data: Data())

    let routeDistance: CLLocationDistance
    let routePoints: [RoutePoint]
    let destination: LocationTarget
    let simulation: WalkingSimulationController
    let isPaired: Bool
    let isRouteSaved: Bool
    let onStart: () -> Void
    let onTogglePause: () -> Void
    let onWalkBack: () -> Void
    let onChooseNewLocation: () -> Void
    let onChangeDestination: () -> Void
    let onSaveRoute: () -> Void
    let onFinishKeepingPosition: () -> Void
    let onFinishRestoringPosition: () -> Void
    let onDone: () -> Void

    @State private var isConfirmingStop = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            cardContent
        }
        .scrollDismissesKeyboard(.interactively)
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.24),
            value: simulation.phase
        )
        .frame(height: panelHeight)
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .starFlyGlass(in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { isSpeedInputFocused = false }
                    .font(.body.weight(.semibold))
            }
        }
        .confirmationDialog(
            "結束步行後的位置",
            isPresented: $isConfirmingStop,
            titleVisibility: .visible
        ) {
            Button("結束並保留位置", action: onFinishKeepingPosition)
            Button("結束並恢復實際位置", action: onFinishRestoringPosition)
            Button("繼續步行", role: .cancel) {}
        } message: {
            Text("你可以保留最後的模擬位置，或停止定位工作階段並恢復 iPhone 的實際位置。")
        }
        .fileExporter(
            isPresented: $isExportingGPX,
            document: gpxExportDocument,
            contentType: .starFlyGPX,
            defaultFilename: GPXRouteCodec.suggestedFilename(for: destination.name)
        ) { _ in }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(.secondary.opacity(0.34))
                .frame(width: 38, height: 4)
                .frame(width: 64, height: 28)
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 8)
                        .onEnded { value in
                            let limit = min(UIScreen.main.bounds.height * 0.78, 720)
                            withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.84)) {
                                panelHeight = min(max(panelHeight - value.translation.height, 280), limit)
                            }
                        }
                )
                .overlay(alignment: .bottom) {
                    Text("上下拖曳")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .offset(y: 8)
                        .allowsHitTesting(false)
                }
                .accessibilityLabel("拖曳調整路線控制面板高度")
                .accessibilityHint("向上展開面板，向下收合面板")
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: phaseSymbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(phaseColour)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey(phaseTitle))
                        .font(.headline)

                    Text(phaseSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                }

                Spacer(minLength: 0)

                if canClose {
                    Button(action: onDone) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(StarFlyPressStyle())
                    .accessibilityLabel("關閉步行路線")
                }
            }

            if showsProgress {
                ProgressView(value: simulation.progress)
                    .tint(.gray)
                    .animation(
                        reduceMotion ? nil : .linear(duration: 0.9),
                        value: simulation.progress
                    )
            }

            routeMetrics

            if canAdjustSpeed {
                speedSlider
            }

            if canConfigureLoop {
                loopSettings
            }

            if canConfigureTraversal {
                traversalSettings
            }

            fluctuationSettings

            controls
            footer
        }
    }

    private var speedSlider: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("移動速度", systemImage: "speedometer")
                    .font(.subheadline.weight(.medium))
                Spacer()
                TextField(
                    "公里/小時",
                    value: speedInKilometresBinding,
                    format: .number.precision(.fractionLength(1))
                )
                .keyboardType(.decimalPad)
                .focused($isSpeedInputFocused)
                .multilineTextAlignment(.trailing)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 86)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.white.opacity(0.2), in: Capsule())
                .accessibilityLabel("移動速度，公里每小時")

                Button {
                    isSpeedInputFocused = false
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(StarFlyPressStyle())
                .accessibilityLabel("關閉速度鍵盤")
            }

            Slider(
                value: speedBinding,
                in: WalkingSimulationController.minimumSpeedMetresPerSecond...WalkingSimulationController.maximumSpeedMetresPerSecond,
                step: 0.1,
                onEditingChanged: { isEditing in
                    if isEditing { isSpeedInputFocused = false }
                }
            )
            .tint(.gray)
            .accessibilityValue(speedText)

            HStack(spacing: 8) {
                speedPreset("步行", kilometresPerHour: 4.5)
                speedPreset("巡航", kilometresPerHour: 18)
                speedPreset("快速", kilometresPerHour: 54)
            }

            Text("範圍 \(speedRangeText) 公里/小時")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .starFlyGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var fluctuationSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("微幅晃動", isOn: fluctuationEnabledBinding)
                .font(.subheadline.weight(.medium))
                .tint(.gray)

            if simulation.fluctuationEnabled {
                HStack {
                    Text("晃動幅度")
                    Spacer()
                    Text("±\(simulation.fluctuationAmplitudeMetres.formatted(.number.precision(.fractionLength(1)))) 公尺")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: fluctuationAmplitudeBinding, in: 0.2...3, step: 0.1)
                    .tint(.gray)
                Text("沿路線微幅偏移，最多 3 公尺。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .starFlyGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.22),
            value: simulation.fluctuationEnabled
        )
    }

    private func speedPreset(_ title: String, kilometresPerHour: Double) -> some View {
        Button(LocalizedStringKey(title)) {
            isSpeedInputFocused = false
            speedInKilometresBinding.wrappedValue = kilometresPerHour
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(.white.opacity(0.15), in: Capsule())
        .buttonStyle(StarFlyPressStyle())
    }

    private var loopSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("路徑循環", systemImage: "repeat")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(loopSummary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            Toggle("無限循環", isOn: repeatsIndefinitelyBinding)
                .tint(.gray)
            if !simulation.repeatsIndefinitely {
                Stepper("執行 \(simulation.loopCount) 圈", value: loopCountBinding, in: 1...99)
            }
        }
        .padding(12)
        .starFlyGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var traversalSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("移動方式", systemImage: "arrow.triangle.swap")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(LocalizedStringKey(simulation.traversalStyle.title))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Picker("移動方式", selection: traversalStyleBinding) {
                ForEach(RouteTraversalStyle.allCases) { style in
                    Text(LocalizedStringKey(style.title)).tag(style)
                }
            }
            .pickerStyle(.segmented)

            if simulation.traversalStyle == .waypointHops {
                HStack {
                    Text("每段步行")
                    Spacer()
                    Text("\(simulation.waypointHoldSeconds.formatted(.number.precision(.fractionLength(0)))) 秒")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: waypointHoldSecondsBinding, in: 0...60, step: 1)
                    .tint(.gray)
            }

            Toggle("顯示路徑通知", isOn: sendsRouteNotificationsBinding)
                .tint(.gray)
        }
        .padding(12)
        .starFlyGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var routeMetrics: some View {
        let distance = RouteMetric(
            title: showsProgress ? "剩餘" : "距離",
            value: distanceText,
            symbol: "point.topleft.down.to.point.bottomright.curvepath"
        )
        let duration = RouteMetric(
            title: simulation.phase == .arrived ? "狀態" : "步行",
            value: durationText,
            symbol: simulation.phase == .arrived ? "checkmark.circle" : "clock"
        )
        let arrival = RouteMetric(
            title: "抵達",
            value: arrivalText,
            symbol: "flag.checkered"
        )

        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                distance
                duration
                arrival
            }
        } else {
            HStack(spacing: 10) {
                distance
                duration
                arrival
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch simulation.phase {
        case .idle:
            Button(action: onStart) {
                Label("開始步行", systemImage: "figure.walk.motion")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isPaired)

            HStack(spacing: 10) {
                Button(action: onChangeDestination) {
                    Label("更改目的地", systemImage: "arrow.triangle.branch")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: onSaveRoute) {
                    Label(isRouteSaved ? "已收藏" : "收藏路徑", systemImage: isRouteSaved ? "heart.fill" : "heart")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.gray)
            }

            Button {
                gpxExportDocument = GPXRouteDocument(
                    data: GPXRouteCodec.encode(points: routePoints, name: destination.name)
                )
                isExportingGPX = true
            } label: {
                Label("匯出 GPX 航線", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

        case .preparing:
            HStack(spacing: 10) {
                ProgressView()
                Text("正在開始步行工作階段⋯")
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)

        case .walking, .paused:
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) {
                        pauseButton
                        stopWalkingButton(showTitle: true)
                    }
                } else {
                    HStack(spacing: 10) {
                        pauseButton
                        stopWalkingButton(showTitle: false)
                    }
                }
            }

            Button(action: onChangeDestination) {
                Label("更改目的地", systemImage: "arrow.triangle.branch")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

        case .arrived:
            Button(action: onFinishKeepingPosition) {
                Label("保留目前位置", systemImage: "location.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.gray)

            Button(action: onFinishRestoringPosition) {
                Label("恢復 iPhone 實際位置", systemImage: "location.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            HStack(spacing: 10) {
                Button(action: onWalkBack) {
                    Label("沿路線返回", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                newLocationButton
            }

        case .stopping:
            HStack(spacing: 10) {
                ProgressView()
                Text("正在還原此 iPhone 的實際位置⋯")
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)

        case .failed:
            Button(action: onStart) {
                Label("再試一次", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isPaired)
        }
    }

    private var pauseButton: some View {
                Button(action: onTogglePause) {
                    Label(
                        simulation.phase == .paused ? "繼續" : "暫停",
                        systemImage: simulation.phase == .paused ? "play.fill" : "pause.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
    }

    @ViewBuilder
    private func stopWalkingButton(showTitle: Bool) -> some View {
                Button {
                    isConfirmingStop = true
                } label: {
            if showTitle {
                Label("結束並保留", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            } else {
                Image(systemName: "stop.fill")
                    .frame(width: 28)
            }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityLabel("結束步行並保留目前位置")
    }

    private var newLocationButton: some View {
        Button(action: onChooseNewLocation) {
            Label("新位置", systemImage: "mappin.and.ellipse")
                    .frame(maxWidth: .infinity)
            }
        .buttonStyle(.bordered)
            .controlSize(.large)
    }

    @ViewBuilder
    private var footer: some View {
        switch simulation.phase {
        case .idle where !isPaired:
            Text("先配對 iPhone")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)
        case .idle:
            EmptyView()

        case .preparing:
            Text("依提示切換行動數據。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)

        case .walking:
            Text("保持 StarFly 開啟；可切換 App。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)

        case .paused:
            EmptyView()

        case .arrived:
            Text("位置會保留，直到你手動還原。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)

        case .stopping:
            Text("保持 StarFly 開啟，直到實際位置還原。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)

        case .failed(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var canClose: Bool {
        switch simulation.phase {
        case .idle, .failed:
            true
        case .preparing, .walking, .paused, .arrived, .stopping:
            false
        }
    }

    private var canAdjustSpeed: Bool {
        switch simulation.phase {
        case .idle, .walking, .paused, .failed:
            true
        case .preparing, .arrived, .stopping:
            false
        }
    }

    private var canConfigureLoop: Bool {
        switch simulation.phase {
        case .idle, .failed:
            true
        case .preparing, .walking, .paused, .arrived, .stopping:
            false
        }
    }

    private var canConfigureTraversal: Bool {
        switch simulation.phase {
        case .idle, .failed:
            true
        case .preparing, .walking, .paused, .arrived, .stopping:
            false
        }
    }

    private var showsProgress: Bool {
        switch simulation.phase {
        case .walking, .paused, .arrived:
            true
        case .idle, .preparing, .stopping, .failed:
            false
        }
    }

    private var phaseTitle: String {
        switch simulation.phase {
        case .idle: "步行路線"
        case .preparing: "正在準備步行"
        case .walking: "步行"
        case .paused: "步行已暫停"
        case .arrived: "已抵達"
        case .stopping: "正在結束步行"
        case .failed: "無法步行"
        }
    }

    private var phaseSubtitle: String {
        let isEnglish = interfaceLanguage == "en"
        let progress = Int((simulation.progress * 100).rounded())
        switch simulation.phase {
        case .idle, .preparing, .failed:
            return isEnglish ? "Current location → \(destination.name)" : "目前位置 → \(destination.name)"
        case .walking, .paused:
            return isEnglish ? "To \(destination.name) · \(progress)%" : "前往 \(destination.name) · \(progress)%"
        case .arrived:
            return isEnglish ? "At \(destination.name)" : "位置目前位於 \(destination.name)"
        case .stopping:
            return isEnglish ? "Restoring this iPhone’s real location" : "正在還原此 iPhone 的實際位置"
        }
    }

    private var phaseSymbol: String {
        switch simulation.phase {
        case .idle, .preparing, .walking: "figure.walk"
        case .paused: "pause.circle.fill"
        case .arrived: "checkmark.circle.fill"
        case .stopping: "location.slash.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var phaseColour: Color {
        switch simulation.phase {
        case .arrived: .primary
        case .failed: .red
        case .idle, .preparing, .walking, .paused, .stopping: .primary
        }
    }

    private var speedBinding: Binding<Double> {
        Binding(
            get: { simulation.paceMetresPerSecond },
            set: { simulation.paceMetresPerSecond = $0 }
        )
    }

    private var traversalStyleBinding: Binding<RouteTraversalStyle> {
        Binding(
            get: { simulation.traversalStyle },
            set: { simulation.traversalStyle = $0 }
        )
    }

    private var waypointHoldSecondsBinding: Binding<Double> {
        Binding(
            get: { simulation.waypointHoldSeconds },
            set: { simulation.waypointHoldSeconds = $0 }
        )
    }

    private var sendsRouteNotificationsBinding: Binding<Bool> {
        Binding(
            get: { simulation.sendsRouteNotifications },
            set: { simulation.sendsRouteNotifications = $0 }
        )
    }

    private var speedInKilometresBinding: Binding<Double> {
        Binding(
            get: { simulation.paceMetresPerSecond * 3.6 },
            set: { value in
                let metresPerSecond = value / 3.6
                simulation.paceMetresPerSecond = min(
                    max(metresPerSecond, WalkingSimulationController.minimumSpeedMetresPerSecond),
                    WalkingSimulationController.maximumSpeedMetresPerSecond
                )
            }
        )
    }

    private var loopCountBinding: Binding<Int> {
        Binding(
            get: { simulation.loopCount },
            set: { simulation.loopCount = $0 }
        )
    }

    private var repeatsIndefinitelyBinding: Binding<Bool> {
        Binding(
            get: { simulation.repeatsIndefinitely },
            set: { simulation.repeatsIndefinitely = $0 }
        )
    }

    private var fluctuationEnabledBinding: Binding<Bool> {
        Binding(
            get: { simulation.fluctuationEnabled },
            set: { simulation.fluctuationEnabled = $0 }
        )
    }

    private var fluctuationAmplitudeBinding: Binding<Double> {
        Binding(
            get: { simulation.fluctuationAmplitudeMetres },
            set: { simulation.fluctuationAmplitudeMetres = $0 }
        )
    }

    private var speedText: String {
        let kilometresPerHour = simulation.paceMetresPerSecond * 3.6
        let value = kilometresPerHour.formatted(
            .number.precision(.fractionLength(1)).locale(Locale(identifier: interfaceLanguage))
        )
        return interfaceLanguage == "en" ? "\(value) km/h" : "\(value) 公里/小時"
    }

    private var speedRangeText: String {
        let minimum = WalkingSimulationController.minimumSpeedMetresPerSecond * 3.6
        let maximum = WalkingSimulationController.maximumSpeedMetresPerSecond * 3.6
        let locale = Locale(identifier: interfaceLanguage)
        let minimumText = minimum.formatted(.number.precision(.fractionLength(1)).locale(locale))
        let maximumText = maximum.formatted(.number.precision(.fractionLength(1)).locale(locale))
        return "\(minimumText)–\(maximumText)"
    }

    private var loopSummary: String {
        if interfaceLanguage == "en" {
            return simulation.repeatsIndefinitely ? "Infinite" : "\(simulation.loopCount) loops"
        }
        return simulation.repeatsIndefinitely ? "無限" : "\(simulation.loopCount) 圈"
    }

    private var distanceText: String {
        let distance = showsProgress ? simulation.remainingDistance : routeDistance
        let locale = Locale(identifier: interfaceLanguage)
        if locale.region?.identifier == "GB" {
            return formatUKDistance(distance)
        }

        let formatter = MeasurementFormatter()
        formatter.locale = locale
        formatter.unitOptions = .naturalScale
        formatter.unitStyle = .short
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter.string(from: Measurement(value: distance, unit: UnitLength.meters))
    }

    private func formatUKDistance(_ distance: CLLocationDistance) -> String {
        let metresPerMile = 1_609.344
        guard distance >= metresPerMile else {
            let yards = max(0, distance / 0.9144)
            return "\(Int(yards.rounded())) yd"
        }

        let miles = distance / metresPerMile
        return miles.formatted(
            .number.precision(.fractionLength(miles < 10 ? 1 : 0))
        ) + " mi"
    }

    private var durationText: String {
        guard simulation.phase != .arrived else { return interfaceLanguage == "en" ? "Done" : "完成" }
        let duration = simulation.totalDistance > 0
            ? simulation.remainingDuration
            : routeDistance / simulation.paceMetresPerSecond
        return formatDuration(duration)
    }

    private var arrivalText: String {
        guard simulation.phase != .arrived else { return "現在" }
        let duration = simulation.totalDistance > 0
            ? simulation.remainingDuration
            : routeDistance / simulation.paceMetresPerSecond
        let format = Date.FormatStyle(
            date: .omitted,
            time: .shortened,
            locale: Locale(identifier: interfaceLanguage)
        )
        return Date.now.addingTimeInterval(duration).formatted(format)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = max(1, Int((duration / 60).rounded()))
        guard minutes >= 60 else {
            return interfaceLanguage == "en" ? "\(minutes) min" : "\(minutes) 分鐘"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if interfaceLanguage == "en" {
            return remainingMinutes == 0 ? "\(hours) hr" : "\(hours) hr \(remainingMinutes) min"
        }
        return remainingMinutes == 0 ? "\(hours) 小時" : "\(hours) 小時 \(remainingMinutes) 分鐘"
    }
}

private struct RouteMetric: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(LocalizedStringKey(title), systemImage: symbol)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .starFlyGlass(in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
    }
}
