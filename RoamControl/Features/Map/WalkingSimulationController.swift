import CoreLocation
import Foundation
import MapKit
import Observation

enum WalkingSimulationPhase: Equatable {
    case idle
    case preparing
    case walking
    case paused
    case arrived
    case stopping
    case failed(String)
}

enum RouteTraversalStyle: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case continuous
    case waypointHops

    var id: String { rawValue }

    var title: String {
        switch self {
        case .continuous: "連續移動"
        case .waypointHops: "逐點跳轉"
        }
    }

    var detail: String {
        switch self {
        case .continuous: "依照設定速度平順移動"
        case .waypointHops: "跳至座標點後步行一段時間，再跳至下一點"
        }
    }
}

@MainActor
@Observable
final class WalkingSimulationController {
    private(set) var phase: WalkingSimulationPhase = .idle
    private(set) var currentCoordinate: CLLocationCoordinate2D?
    private(set) var distanceTravelled: CLLocationDistance = 0
    private(set) var totalDistance: CLLocationDistance = 0
    /// 1.8–72 km/h gives testing flexibility while retaining fine control.
    static let minimumSpeedMetresPerSecond = 0.5
    static let maximumSpeedMetresPerSecond = 20.0
    /// The initial pace is 19.8 km/h (5.5 m/s).
    var paceMetresPerSecond = 5.5
    var traversalStyle: RouteTraversalStyle = .continuous
    var waypointHoldSeconds: TimeInterval = 3
    var sendsRouteNotifications = true
    var fluctuationEnabled = false
    var fluctuationAmplitudeMetres = 1.2
    private(set) var supportsWaypointNavigation = false
    private(set) var currentWaypointIndex = 0

    func finishKeepingCurrentLocation(using deviceSession: LocalDeviceSessionCoordinator) {
        guard phase == .walking || phase == .paused else { return }
        movementTask?.cancel()
        movementTask = nil

        guard let coordinate = currentCoordinate, let destination else {
            phase = .arrived
            return
        }

        let heldTarget = movementTarget(at: coordinate, destination: destination, applyingFluctuation: false)
        guard deviceSession.updateLocation(heldTarget) == .updated else {
            phase = .failed("無法保留目前的模擬位置。")
            return
        }
        phase = .arrived
        notify(title: "StarFly 已保留位置", body: "路徑已停止，模擬位置會維持在最後一點。")
        endLiveActivity(status: activityText("位置已保留", "Position held"))
    }
    var loopCount = 1
    var repeatsIndefinitely = false
    private(set) var completedLaps = 0

    @ObservationIgnored
    private var routePoints: [MKMapPoint] = []
    @ObservationIgnored
    private var activeDeviceSession: LocalDeviceSessionCoordinator?
    @ObservationIgnored
    private var waypointNavigationObserver: NSObjectProtocol?
    @ObservationIgnored
    private var speedAdjustmentObserver: NSObjectProtocol?
    @ObservationIgnored
    private var pauseToggleObserver: NSObjectProtocol?
    @ObservationIgnored
    private var cumulativeDistances: [CLLocationDistance] = []
    @ObservationIgnored
    private(set) var destination: LocationTarget?
    @ObservationIgnored
    private var routeStart: LocationTarget?
    @ObservationIgnored
    private var movementTask: Task<Void, Never>?
    @ObservationIgnored
    private var fluctuationStartOffsetMetres = 0.0
    @ObservationIgnored
    private var fluctuationTargetOffsetMetres = 0.0
    @ObservationIgnored
    private var fluctuationStartedAt = Date.distantPast
    @ObservationIgnored
    private var fluctuationDuration: TimeInterval = 0
    @ObservationIgnored
    private var nextFluctuationAt = Date.distantPast
    @ObservationIgnored
    private var lastLiveActivityUpdateAt = Date.distantPast

    init() {
        waypointNavigationObserver = NotificationCenter.default.addObserver(
            forName: .starFlyLiveActivityWaypointNavigation,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let offset = notification.userInfo?["offset"] as? Int, offset != 0 else { return }
            Task { @MainActor [weak self] in
                self?.navigateToWaypoint(offset: offset)
            }
        }
        speedAdjustmentObserver = NotificationCenter.default.addObserver(
            forName: .starFlyLiveActivitySpeedAdjustment,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let delta = notification.userInfo?["deltaKilometresPerHour"] as? Double else { return }
            Task { @MainActor [weak self] in
                self?.adjustSpeed(byKilometresPerHour: delta)
            }
        }
        pauseToggleObserver = NotificationCenter.default.addObserver(
            forName: .starFlyLiveActivityPauseToggle,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.togglePause()
            }
        }
    }

    deinit {
        if let waypointNavigationObserver {
            NotificationCenter.default.removeObserver(waypointNavigationObserver)
        }
        if let speedAdjustmentObserver {
            NotificationCenter.default.removeObserver(speedAdjustmentObserver)
        }
        if let pauseToggleObserver {
            NotificationCenter.default.removeObserver(pauseToggleObserver)
        }
    }

    var progress: Double {
        guard totalDistance > 0 else { return 0 }
        return min(max(distanceTravelled / totalDistance, 0), 1)
    }

    var remainingDistance: CLLocationDistance {
        max(totalDistance - distanceTravelled, 0)
    }

    var remainingDuration: TimeInterval {
        remainingDistance / paceMetresPerSecond
    }

    var locksDestination: Bool {
        switch phase {
        case .preparing, .walking, .paused, .arrived, .stopping:
            true
        case .idle, .failed:
            false
        }
    }

    func prepare(route: MKRoute, destination: LocationTarget) {
        prepare(polyline: route.polyline, destination: destination)
    }

    func prepare(
        polyline: MKPolyline,
        destination: LocationTarget,
        supportsWaypointNavigation: Bool = false
    ) {
        movementTask?.cancel()
        movementTask = nil
        resetFluctuation()

        let points = polyline.points()
        routePoints = (0..<polyline.pointCount).map { points[$0] }
        cumulativeDistances = cumulativeDistanceValues(for: routePoints)
        totalDistance = cumulativeDistances.last ?? 0
        distanceTravelled = 0
        completedLaps = 0
        currentWaypointIndex = 0
        self.supportsWaypointNavigation = supportsWaypointNavigation
        currentCoordinate = nil
        self.destination = destination
        if let startCoordinate = routePoints.first?.coordinate {
            routeStart = LocationTarget(
                name: "路線起點",
                subtitle: "\(destination.name) 的起點",
                latitude: startCoordinate.latitude,
                longitude: startCoordinate.longitude
            )
        } else {
            routeStart = nil
        }
        phase = routePoints.count >= 2 ? .idle : .failed("此路徑沒有足夠的座標點可供模擬移動。")
    }

    func replaceCurrentRoute(
        with route: MKRoute,
        destination: LocationTarget,
        using deviceSession: LocalDeviceSessionCoordinator
    ) {
        guard phase == .walking || phase == .paused,
              let currentCoordinate,
              route.polyline.pointCount >= 2
        else { return }

        let shouldResume = phase == .walking
        movementTask?.cancel()
        movementTask = nil
        resetFluctuation()

        let points = route.polyline.points()
        var replacementPoints = (0..<route.polyline.pointCount).map { points[$0] }
        if let first = replacementPoints.first {
            let source = CLLocation(latitude: currentCoordinate.latitude, longitude: currentCoordinate.longitude)
            let routeStart = CLLocation(latitude: first.coordinate.latitude, longitude: first.coordinate.longitude)
            if source.distance(from: routeStart) > 1 {
                replacementPoints.insert(MKMapPoint(currentCoordinate), at: 0)
            }
        }

        routePoints = replacementPoints
        cumulativeDistances = cumulativeDistanceValues(for: routePoints)
        totalDistance = cumulativeDistances.last ?? route.distance
        distanceTravelled = 0
        completedLaps = 0
        currentWaypointIndex = 0
        supportsWaypointNavigation = false
        activeDeviceSession = deviceSession
        self.destination = destination
        routeStart = LocationTarget(
            name: "新路線起點",
            subtitle: "中途改道時的位置",
            latitude: currentCoordinate.latitude,
            longitude: currentCoordinate.longitude
        )
        phase = shouldResume ? .walking : .paused
        beginMovement(using: deviceSession)
        syncLiveActivity(status: phase == .paused
            ? activityText("步行已暫停", "Paused")
            : activityText("正在前往", "On the way"))
    }

    func prepareReturnTrip() -> LocationTarget? {
        guard
            phase == .arrived,
            let returnDestination = routeStart,
            let previousDestination = destination,
            routePoints.count >= 2
        else { return nil }

        movementTask?.cancel()
        movementTask = nil
        routePoints.reverse()
        cumulativeDistances = cumulativeDistanceValues(for: routePoints)
        totalDistance = cumulativeDistances.last ?? totalDistance
        distanceTravelled = 0
        completedLaps = 0
        currentWaypointIndex = 0
        currentCoordinate = nil
        destination = returnDestination
        routeStart = previousDestination
        phase = .idle
        return returnDestination
    }

    func start(using appModel: AppModel) async {
        guard
            !routePoints.isEmpty,
            let destination,
            phase == .idle || isFailed
        else { return }
        guard case .paired = appModel.pairingStatus else {
            phase = .failed("開始步行工作階段前，請先配對此 iPhone。")
            return
        }

        movementTask?.cancel()
        distanceTravelled = 0
        currentWaypointIndex = 0
        activeDeviceSession = appModel.deviceSession
        let initialTarget = movementTarget(at: routePoints[0].coordinate, destination: destination)
        currentCoordinate = initialTarget.coordinate
        phase = .preparing

        await appModel.startWalkingLocationSession(
            at: initialTarget,
            destination: destination,
            paceMetresPerSecond: paceMetresPerSecond
        )

        if case .idle = appModel.deviceSession.phase, phase == .preparing {
            phase = .failed("無法開始步行工作階段。")
        }
    }

    func togglePause() {
        switch phase {
        case .walking:
            phase = .paused
        case .paused:
            phase = .walking
        case .idle, .preparing, .arrived, .stopping, .failed:
            break
        }
        if phase == .walking || phase == .paused {
            syncLiveActivity(status: phase == .paused
                ? activityText("步行已暫停", "Paused")
                : activityText("正在前往", "On the way"))
        }
    }

    func stop(using deviceSession: LocalDeviceSessionCoordinator) {
        guard locksDestination || isFailed else { return }
        movementTask?.cancel()
        movementTask = nil

        if case .idle = deviceSession.phase {
            currentCoordinate = nil
            distanceTravelled = 0
            phase = .idle
            endLiveActivity(status: activityText("已結束", "Ended"))
            return
        }

        phase = .stopping
        endLiveActivity(status: activityText("正在結束", "Ending"))
        deviceSession.stop()
    }

    func handleDeviceSessionPhase(
        _ devicePhase: DeviceSessionPhase,
        deviceSession: LocalDeviceSessionCoordinator
    ) {
        switch devicePhase {
        case .active:
            guard phase == .preparing else { return }
            activeDeviceSession = deviceSession
            phase = .walking
            notify(title: "StarFly 已開始", body: traversalStyle.detail)
            syncLiveActivity(status: activityText("正在前往", "On the way"))
            beginMovement(using: deviceSession)

        case .stopping:
            if locksDestination || isFailed {
                movementTask?.cancel()
                movementTask = nil
                phase = .stopping
                endLiveActivity(status: activityText("正在結束", "Ending"))
            }

        case .idle:
            guard phase == .stopping else { return }
            movementTask?.cancel()
            movementTask = nil
            currentCoordinate = nil
            distanceTravelled = 0
            phase = .idle
            endLiveActivity(status: activityText("已結束", "Ended"))

        case .failed(let message):
            guard locksDestination || phase == .preparing else { return }
            movementTask?.cancel()
            movementTask = nil
            currentCoordinate = nil
            phase = .failed(message)
            endLiveActivity(status: activityText("路徑已停止", "Route stopped"))

        case .openingLocalDevVPN, .discovering, .connecting:
            break
        }
    }

    func reset() {
        movementTask?.cancel()
        movementTask = nil
        endLiveActivity(status: activityText("已結束", "Ended"))
        resetFluctuation()
        routePoints = []
        cumulativeDistances = []
        supportsWaypointNavigation = false
        currentWaypointIndex = 0
        activeDeviceSession = nil
        destination = nil
        routeStart = nil
        currentCoordinate = nil
        distanceTravelled = 0
        totalDistance = 0
        completedLaps = 0
        phase = .idle
    }

    private var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    private func beginMovement(using deviceSession: LocalDeviceSessionCoordinator) {
        movementTask?.cancel()
        movementTask = Task { @MainActor [weak self, weak deviceSession] in
            guard let self, let deviceSession else { return }
            if self.traversalStyle == .waypointHops {
                await self.runWaypointHops(using: deviceSession)
                return
            }

            var lastTick = Date.now

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }

                let now = Date.now
                let elapsed = now.timeIntervalSince(lastTick)
                lastTick = now

                if self.phase == .paused {
                    continue
                }
                guard self.phase == .walking, let destination = self.destination else { return }

                self.distanceTravelled = min(
                    self.totalDistance,
                    self.distanceTravelled + (self.paceMetresPerSecond * elapsed)
                )
                self.currentWaypointIndex = self.pointIndex(atOrBefore: self.distanceTravelled)

                guard let coordinate = self.coordinate(at: self.distanceTravelled) else {
                    self.phase = .failed("無法沿著這條路徑移動。")
                    self.endLiveActivity(status: self.activityText("路徑已停止", "Route stopped"))
                    return
                }

                let reachedDestination = self.distanceTravelled >= self.totalDistance
                let target = reachedDestination
                    ? destination
                    : self.movementTarget(at: coordinate, destination: destination)
                self.currentCoordinate = target.coordinate

                guard deviceSession.updateLocation(target) == .updated else {
                    self.phase = .failed("步行完成前，位置工作階段已結束。")
                    self.endLiveActivity(status: self.activityText("路徑已停止", "Route stopped"))
                    return
                }
                self.refreshLiveActivityIfNeeded()

                if reachedDestination {
                    self.completedLaps += 1
                    if self.repeatsIndefinitely || self.completedLaps < self.loopCount {
                        self.distanceTravelled = 0
                        self.currentWaypointIndex = 0
                        self.currentCoordinate = self.routePoints[0].coordinate
                        continue
                    }
                    self.currentCoordinate = destination.coordinate
                    self.phase = .arrived
                    self.notify(title: "StarFly 路徑完成", body: "已抵達 \(destination.name)。")
                    self.endLiveActivity(status: self.activityText("已抵達", "Arrived"))
                    return
                }
            }
        }
    }

    private func runWaypointHops(using deviceSession: LocalDeviceSessionCoordinator) async {
        guard routePoints.count >= 2, let destination else { return }

        while !Task.isCancelled {
        guard phase == .walking || phase == .paused || phase == .arrived else { return }
            if phase == .paused {
                try? await Task.sleep(for: .milliseconds(250))
                continue
            }

            let pointIndex = min(max(currentWaypointIndex, 0), routePoints.count - 1)
            let coordinate = routePoints[pointIndex].coordinate
            let target = pointIndex == routePoints.count - 1
                ? destination
                : movementTarget(at: coordinate, destination: destination)
            guard deviceSession.updateLocation(target) == .updated else {
                phase = .failed("跳轉座標時，位置工作階段已結束。")
                endLiveActivity(status: activityText("路徑已停止", "Route stopped"))
                return
            }

            distanceTravelled = cumulativeDistances[pointIndex]
            currentCoordinate = target.coordinate
            notify(
                title: "StarFly 跳點 \(pointIndex + 1)/\(routePoints.count)",
                body: pointIndex == routePoints.count - 1 ? "已抵達 \(destination.name)。" : "步行 \(holdSecondsText) 後跳至下一點。"
            )
            refreshLiveActivityIfNeeded()

            if pointIndex == routePoints.count - 1 {
                completedLaps += 1
                if repeatsIndefinitely || completedLaps < loopCount {
                    currentWaypointIndex = 0
                    distanceTravelled = 0
                    continue
                }
                phase = .arrived
                notify(title: "StarFly 路徑完成", body: "已抵達 \(destination.name)。")
                endLiveActivity(status: activityText("已抵達", "Arrived"))
                return
            }

            await walkBrieflyTowardNextPoint(
                from: pointIndex,
                using: deviceSession,
                destination: destination
            )
            guard !Task.isCancelled else { return }
            guard currentWaypointIndex == pointIndex else { continue }
            currentWaypointIndex = pointIndex + 1
        }
    }

    private func walkBrieflyTowardNextPoint(
        from pointIndex: Int,
        using deviceSession: LocalDeviceSessionCoordinator,
        destination: LocationTarget
    ) async {
        let walkDuration = max(waypointHoldSeconds, 0)
        guard walkDuration > 0 else { return }
        let segmentStart = cumulativeDistances[pointIndex]
        let segmentEnd = cumulativeDistances[pointIndex + 1]
        let segmentLength = segmentEnd - segmentStart
        guard segmentLength > 0 else { return }

        var walkedSeconds: TimeInterval = 0
        while walkedSeconds < walkDuration, !Task.isCancelled {
            guard currentWaypointIndex == pointIndex else { return }
            if phase == .paused {
                try? await Task.sleep(for: .milliseconds(250))
                continue
            }
            guard phase == .walking else { return }

            let step = min(1, walkDuration - walkedSeconds)
            try? await Task.sleep(nanoseconds: UInt64(step * 1_000_000_000))
            guard !Task.isCancelled else { return }
            if phase == .paused { continue }
            guard phase == .walking else { return }
            guard currentWaypointIndex == pointIndex else { return }
            walkedSeconds += step

            let travelledOnSegment = min(segmentLength, paceMetresPerSecond * walkedSeconds)
            guard let coordinate = coordinate(at: segmentStart + travelledOnSegment) else { return }
            distanceTravelled = segmentStart + travelledOnSegment
            let target = movementTarget(at: coordinate, destination: destination)
            currentCoordinate = target.coordinate
            guard deviceSession.updateLocation(target) == .updated else {
                phase = .failed("逐點步行時，位置工作階段已結束。")
                endLiveActivity(status: activityText("路徑已停止", "Route stopped"))
                return
            }
            refreshLiveActivityIfNeeded()
        }
    }

    private var holdSecondsText: String {
        waypointHoldSeconds.formatted(.number.precision(.fractionLength(0))) + " 秒"
    }

    private func refreshLiveActivityIfNeeded() {
        guard Date.now.timeIntervalSince(lastLiveActivityUpdateAt) >= 5 else { return }
        syncLiveActivity(status: phase == .paused
            ? activityText("步行已暫停", "Paused")
            : activityText("正在前往", "On the way"))
    }

    private func syncLiveActivity(status: String) {
        guard let destination else { return }
        let state = StarFlyWalkingActivityAttributes.ContentState(
            destinationName: destination.name,
            speedKilometresPerHour: paceMetresPerSecond * 3.6,
            progress: progress,
            remainingDistanceMetres: remainingDistance,
            remainingDistanceDescription: formattedRemainingDistance,
            estimatedArrival: Date.now.addingTimeInterval(remainingDuration),
            status: status,
            supportsWaypointNavigation: supportsWaypointNavigation,
            waypointIndex: supportsWaypointNavigation ? currentWaypointIndex + 1 : nil,
            waypointCount: supportsWaypointNavigation ? routePoints.count : nil,
            previousWaypointTitle: supportsWaypointNavigation ? activityText("上一個路徑點", "Previous route point") : nil,
            nextWaypointTitle: supportsWaypointNavigation ? activityText("下一個路徑點", "Next route point") : nil,
            decreaseSpeedTitle: activityText("降低速度", "Decrease speed"),
            increaseSpeedTitle: activityText("提高速度", "Increase speed"),
            speedAdjustmentEnabled: true,
            pauseTitle: phase == .paused
                ? activityText("繼續步行", "Resume walking")
                : activityText("暫停步行", "Pause walking"),
            isPaused: phase == .paused,
            pauseEnabled: true
        )
        lastLiveActivityUpdateAt = .now
        Task { await WalkingLiveActivityManager.shared.updateOrStart(state) }
    }

    private func endLiveActivity(status: String) {
        guard let destination else { return }
        let canNavigateWaypoints = supportsWaypointNavigation && (phase == .walking || phase == .paused)
        let state = StarFlyWalkingActivityAttributes.ContentState(
            destinationName: destination.name,
            speedKilometresPerHour: paceMetresPerSecond * 3.6,
            progress: progress,
            remainingDistanceMetres: remainingDistance,
            remainingDistanceDescription: formattedRemainingDistance,
            estimatedArrival: .now,
            status: status,
            supportsWaypointNavigation: canNavigateWaypoints,
            waypointIndex: canNavigateWaypoints ? currentWaypointIndex + 1 : nil,
            waypointCount: canNavigateWaypoints ? routePoints.count : nil,
            previousWaypointTitle: canNavigateWaypoints ? activityText("上一個路徑點", "Previous route point") : nil,
            nextWaypointTitle: canNavigateWaypoints ? activityText("下一個路徑點", "Next route point") : nil,
            decreaseSpeedTitle: nil,
            increaseSpeedTitle: nil,
            speedAdjustmentEnabled: false,
            pauseTitle: nil,
            isPaused: false,
            pauseEnabled: false
        )
        Task { await WalkingLiveActivityManager.shared.end(with: state) }
    }

    private func navigateToWaypoint(offset: Int) {
        guard supportsWaypointNavigation,
              phase == .walking || phase == .paused,
              !routePoints.isEmpty,
              let destination,
              let activeDeviceSession
        else { return }

        let baseIndex: Int
        if traversalStyle == .waypointHops {
            baseIndex = currentWaypointIndex
        } else {
            baseIndex = pointIndex(atOrBefore: distanceTravelled)
        }
        let nextIndex = min(max(baseIndex + offset, 0), routePoints.count - 1)
        guard nextIndex != baseIndex else { return }

        currentWaypointIndex = nextIndex
        distanceTravelled = cumulativeDistances[nextIndex]
        let target = movementTarget(
            at: routePoints[nextIndex].coordinate,
            destination: destination,
            applyingFluctuation: false
        )
        currentCoordinate = target.coordinate
        guard activeDeviceSession.updateLocation(target) == .updated else {
            phase = .failed("無法切換路徑點，位置工作階段已結束。")
            endLiveActivity(status: activityText("路徑已停止", "Route stopped"))
            return
        }

        syncLiveActivity(status: phase == .paused
            ? activityText("步行已暫停", "Paused")
            : activityText("正在前往", "On the way"))
    }

    private func adjustSpeed(byKilometresPerHour delta: Double) {
        guard phase == .walking || phase == .paused,
              activeDeviceSession != nil,
              delta.isFinite,
              delta != 0
        else { return }

        let adjustedSpeed = paceMetresPerSecond + delta / 3.6
        let boundedSpeed = min(
            max(adjustedSpeed, Self.minimumSpeedMetresPerSecond),
            Self.maximumSpeedMetresPerSecond
        )
        guard abs(boundedSpeed - paceMetresPerSecond) > .ulpOfOne else { return }
        paceMetresPerSecond = boundedSpeed
        syncLiveActivity(status: phase == .paused
            ? activityText("步行已暫停", "Paused")
            : activityText("正在前往", "On the way"))
    }

    private var formattedRemainingDistance: String {
        if remainingDistance >= 1_000 {
            let kilometres = (remainingDistance / 1_000).formatted(.number.precision(.fractionLength(1)))
            return activityText("剩餘 \(kilometres) 公里", "\(kilometres) km remaining")
        }
        let metres = Int(remainingDistance.rounded()).formatted()
        return activityText("剩餘 \(metres) 公尺", "\(metres) m remaining")
    }

    private func activityText(_ chinese: String, _ english: String) -> String {
        UserDefaults.standard.string(forKey: "starfly.interfaceLanguage") == "en" ? english : chinese
    }

    private func notify(title: String, body: String) {
        guard sendsRouteNotifications else { return }
        Task { await RouteNotificationManager.post(title: title, body: body) }
    }

    private func cumulativeDistanceValues(for points: [MKMapPoint]) -> [CLLocationDistance] {
        guard !points.isEmpty else { return [] }

        var values: [CLLocationDistance] = [0]
        values.reserveCapacity(points.count)
        for index in 1..<points.count {
            values.append(
                values[index - 1] + points[index - 1].distance(to: points[index])
            )
        }
        return values
    }

    private func coordinate(at distance: CLLocationDistance) -> CLLocationCoordinate2D? {
        guard let first = routePoints.first else { return nil }
        guard routePoints.count > 1, totalDistance > 0 else { return first.coordinate }
        if distance <= 0 { return first.coordinate }
        if distance >= totalDistance { return routePoints.last?.coordinate }

        let upperIndex = pointIndex(atOrAfter: distance) ?? (routePoints.count - 1)
        let lowerIndex = max(upperIndex - 1, 0)
        let lowerDistance = cumulativeDistances[lowerIndex]
        let upperDistance = cumulativeDistances[upperIndex]
        let segmentLength = upperDistance - lowerDistance
        guard segmentLength > 0 else { return routePoints[upperIndex].coordinate }

        let fraction = (distance - lowerDistance) / segmentLength
        let start = routePoints[lowerIndex]
        let end = routePoints[upperIndex]
        return MKMapPoint(
            x: start.x + ((end.x - start.x) * fraction),
            y: start.y + ((end.y - start.y) * fraction)
        ).coordinate
    }

    private func pointIndex(atOrBefore distance: CLLocationDistance) -> Int {
        guard !cumulativeDistances.isEmpty else { return 0 }
        var lower = 0
        var upper = cumulativeDistances.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if cumulativeDistances[middle] <= distance {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return min(max(lower - 1, 0), cumulativeDistances.count - 1)
    }

    private func pointIndex(atOrAfter distance: CLLocationDistance) -> Int? {
        guard !cumulativeDistances.isEmpty else { return nil }
        var lower = 0
        var upper = cumulativeDistances.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if cumulativeDistances[middle] < distance {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower < cumulativeDistances.count ? lower : nil
    }

    private func movementTarget(
        at coordinate: CLLocationCoordinate2D,
        destination: LocationTarget,
        applyingFluctuation: Bool = true
    ) -> LocationTarget {
        let adjustedCoordinate = applyingFluctuation ? fluctuatedCoordinate(at: coordinate) : coordinate
        return LocationTarget(
            name: "步行前往 \(destination.name)",
            subtitle: "已完成 \(Int((progress * 100).rounded()))%",
            latitude: adjustedCoordinate.latitude,
            longitude: adjustedCoordinate.longitude
        )
    }

    private func fluctuatedCoordinate(at coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        guard
            fluctuationEnabled,
            fluctuationAmplitudeMetres > 0,
            routePoints.count >= 2,
            !cumulativeDistances.isEmpty
        else {
            fluctuationStartOffsetMetres = 0
            fluctuationTargetOffsetMetres = 0
            return coordinate
        }

        let upperIndex = pointIndex(atOrAfter: distanceTravelled) ?? (routePoints.count - 1)
        let startIndex = min(max(upperIndex - 1, 0), routePoints.count - 2)
        let start = routePoints[startIndex]
        let end = routePoints[startIndex + 1]
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let segmentLength = hypot(deltaX, deltaY)
        guard segmentLength > 0 else { return coordinate }

        let now = Date.now
        let amplitude = min(max(fluctuationAmplitudeMetres, 0), 3)
        if now >= nextFluctuationAt {
            let transitionProgress = fluctuationDuration > 0
                ? min(max(now.timeIntervalSince(fluctuationStartedAt) / fluctuationDuration, 0), 1)
                : 1
            let smoothProgress = transitionProgress * transitionProgress * (3 - 2 * transitionProgress)
            let currentOffset = fluctuationStartOffsetMetres
                + ((fluctuationTargetOffsetMetres - fluctuationStartOffsetMetres) * smoothProgress)
            fluctuationStartOffsetMetres = currentOffset
            fluctuationTargetOffsetMetres = Double.random(in: -amplitude...amplitude)
            fluctuationStartedAt = now
            fluctuationDuration = Double.random(in: 0.45...1.6)
            nextFluctuationAt = now.addingTimeInterval(Double.random(in: 2.0...5.5))
        }

        let transitionProgress = fluctuationDuration > 0
            ? min(max(now.timeIntervalSince(fluctuationStartedAt) / fluctuationDuration, 0), 1)
            : 1
        let smoothProgress = transitionProgress * transitionProgress * (3 - 2 * transitionProgress)
        let offsetMetres = fluctuationStartOffsetMetres
            + ((fluctuationTargetOffsetMetres - fluctuationStartOffsetMetres) * smoothProgress)
        let offsetMapPoints = offsetMetres / MKMetersPerMapPointAtLatitude(coordinate.latitude)
        let mapPoint = MKMapPoint(coordinate)
        return MKMapPoint(
            x: mapPoint.x - (deltaY / segmentLength * offsetMapPoints),
            y: mapPoint.y + (deltaX / segmentLength * offsetMapPoints)
        ).coordinate
    }

    private func resetFluctuation() {
        fluctuationStartOffsetMetres = 0
        fluctuationTargetOffsetMetres = 0
        fluctuationStartedAt = .distantPast
        fluctuationDuration = 0
        nextFluctuationAt = .distantPast
    }
}
