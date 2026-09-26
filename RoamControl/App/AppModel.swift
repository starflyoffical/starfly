import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private static let onboardingKey = "hasCompletedOnboarding"
    private static let favouritesKey = "favouriteLocations"
    private static let favouriteRoutesKey = "favouriteRoutes"
    private static let hasSeenFavouriteReorderHintKey = "hasSeenFavouriteReorderHint"
    private static let historyKey = "locationHistory"
    private static let appearanceKey = "appAppearance"
    private static let mapDisplayStyleKey = "mapDisplayStyle"
    private static let activeSessionRecoveryKey = "activeSessionRecovery"

    private let preferences: UserDefaults

    private(set) var hasCompletedOnboarding: Bool
    private(set) var shouldPresentDeviceSetup = false
    private(set) var connectionState: ConnectionState = .notConfigured
    private(set) var pairingStatus: PairingStatus = .checking
    private(set) var selectedTarget: LocationTarget?
    private(set) var favouriteLocations: [LocationTarget]
    private(set) var favouriteRoutes: [SavedRoute]
    private(set) var hasSeenFavouriteReorderHint: Bool
    private(set) var locationHistory: [LocationTarget]
    private(set) var appearance: AppAppearance
    private(set) var mapDisplayStyle: MapDisplayStyle
    private(set) var interruptedSession: SessionRecoveryRecord?
    private(set) var isRestoringInterruptedSession = false
    private(set) var interruptedSessionError: String?

    private var activeSessionRecovery: SessionRecoveryRecord?
    private var lastRecoverySaveDate: Date?
    private var restorationReachedActiveSession = false
    private var restorationWasCancelled = false
    private var isStoppingLocationSessionForRestoration = false

    let pairingService: any PairingService
    let onDevicePairing: OnDevicePairingCoordinator
    let deviceSession: LocalDeviceSessionCoordinator
    let localDevVPNInstallURL = URL(string: "https://apps.apple.com/app/localdevvpn/id6755608044")!

    init(
        pairingService: any PairingService = SecurePairingService(),
        preferences: UserDefaults = .standard
    ) {
        self.pairingService = pairingService
        self.onDevicePairing = .shared
        self.deviceSession = LocalDeviceSessionCoordinator()
        self.preferences = preferences
        let hasCompletedOnboarding = preferences.bool(forKey: Self.onboardingKey)
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.favouriteLocations = Self.locations(forKey: Self.favouritesKey, in: preferences)
        self.favouriteRoutes = Self.routes(forKey: Self.favouriteRoutesKey, in: preferences)
        self.hasSeenFavouriteReorderHint = preferences.bool(forKey: Self.hasSeenFavouriteReorderHintKey)
        self.locationHistory = Self.locations(forKey: Self.historyKey, in: preferences)
        self.appearance = AppAppearance(
            rawValue: preferences.string(forKey: Self.appearanceKey) ?? ""
        ) ?? .automatic
        self.mapDisplayStyle = MapDisplayStyle(
            rawValue: preferences.string(forKey: Self.mapDisplayStyleKey) ?? ""
        ) ?? .standard
        self.interruptedSession = Self.recoveryRecord(in: preferences)
        deviceSession.onPhaseChange = { [weak self] phase in
            self?.applyDeviceSessionPhase(phase)
        }
    }

    func chooseTarget(_ target: LocationTarget) {
        selectedTarget = target
        addToHistory(target)
    }

    func isFavourite(_ target: LocationTarget) -> Bool {
        favouriteLocations.contains { $0.id == target.id }
    }

    func toggleFavourite(_ target: LocationTarget) {
        if let index = favouriteLocations.firstIndex(where: { $0.id == target.id }) {
            favouriteLocations.remove(at: index)
        } else {
            favouriteLocations.insert(target, at: 0)
        }
        save(favouriteLocations, forKey: Self.favouritesKey)
    }

    func removeFavourite(_ target: LocationTarget) {
        favouriteLocations.removeAll { $0.id == target.id }
        save(favouriteLocations, forKey: Self.favouritesKey)
    }

    func saveRoute(_ route: SavedRoute) {
        guard !favouriteRoutes.contains(where: { $0.points == route.points }) else { return }
        favouriteRoutes.insert(route, at: 0)
        save(favouriteRoutes, forKey: Self.favouriteRoutesKey)
    }

    func removeFavouriteRoute(_ route: SavedRoute) {
        favouriteRoutes.removeAll { $0.id == route.id }
        save(favouriteRoutes, forKey: Self.favouriteRoutesKey)
    }

    func clearFavouriteRoutes() {
        favouriteRoutes = []
        preferences.removeObject(forKey: Self.favouriteRoutesKey)
    }

    func moveFavouriteLocations(from source: IndexSet, to destination: Int) {
        favouriteLocations.move(fromOffsets: source, toOffset: destination)
        save(favouriteLocations, forKey: Self.favouritesKey)
        dismissFavouriteReorderHint()
    }

    func dismissFavouriteReorderHint() {
        guard !hasSeenFavouriteReorderHint else { return }
        hasSeenFavouriteReorderHint = true
        preferences.set(true, forKey: Self.hasSeenFavouriteReorderHintKey)
    }

    func renameFavourite(_ target: LocationTarget, to proposedName: String) {
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !name.isEmpty,
            let index = favouriteLocations.firstIndex(where: { $0.id == target.id })
        else { return }

        let renamed = LocationTarget(
            name: name,
            subtitle: target.subtitle,
            latitude: target.latitude,
            longitude: target.longitude
        )
        favouriteLocations[index] = renamed
        if selectedTarget?.id == target.id {
            selectedTarget = renamed
        }
        save(favouriteLocations, forKey: Self.favouritesKey)
    }

    func removeFromHistory(_ target: LocationTarget) {
        locationHistory.removeAll { $0.id == target.id }
        save(locationHistory, forKey: Self.historyKey)
    }

    func clearLocationHistory() {
        locationHistory = []
        preferences.removeObject(forKey: Self.historyKey)
    }

    func clearFavouriteLocations() {
        favouriteLocations = []
        favouriteRoutes = []
        preferences.removeObject(forKey: Self.favouritesKey)
    }

    func setAppearance(_ appearance: AppAppearance) {
        self.appearance = appearance
        preferences.set(appearance.rawValue, forKey: Self.appearanceKey)
    }

    func setMapDisplayStyle(_ style: MapDisplayStyle) {
        mapDisplayStyle = style
        preferences.set(style.rawValue, forKey: Self.mapDisplayStyleKey)
    }

    func completeOnboarding() {
        preferences.set(true, forKey: Self.onboardingKey)
        shouldPresentDeviceSetup = true
        hasCompletedOnboarding = true
    }

    func deviceSetupWasPresented() {
        shouldPresentDeviceSetup = false
    }

    func resetApp() async throws {
        onDevicePairing.reset()
        deviceSession.reset()
        try await pairingService.removeRecord()

        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            preferences.removePersistentDomain(forName: bundleIdentifier)
        } else {
            preferences.removeObject(forKey: Self.onboardingKey)
        }

        selectedTarget = nil
        favouriteLocations = []
        locationHistory = []
        appearance = .automatic
        mapDisplayStyle = .standard
        interruptedSession = nil
        activeSessionRecovery = nil
        isRestoringInterruptedSession = false
        interruptedSessionError = nil
        restorationWasCancelled = false
        pairingStatus = .notPaired
        connectionState = .notConfigured
        shouldPresentDeviceSetup = false
        hasCompletedOnboarding = false
    }

    func restorePairingStatus() async {
        pairingStatus = .checking

        do {
            if let summary = try await pairingService.storedRecord() {
                pairingStatus = .paired(summary)
                if deviceSession.phase == .idle {
                    connectionState = .ready
                }
            } else {
                pairingStatus = .notPaired
                connectionState = .notConfigured
            }
        } catch {
            pairingStatus = .failed(message: error.localizedDescription)
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    func importPairingRecord(from url: URL) async {
        pairingStatus = .importing

        do {
            let summary = try await pairingService.importRecord(from: url)
            pairingStatus = .paired(summary)
            connectionState = .ready
        } catch {
            pairingStatus = .failed(message: error.localizedDescription)
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    func startOnDevicePairing() {
        onDevicePairing.start { [weak self] record, hostAltIRK in
            guard let self else {
                throw PairingServiceError.corruptStoredRecord
            }

            let summary = try await self.pairingService.storeGeneratedRecord(
                record,
                hostAltIRK: hostAltIRK
            )
            self.pairingStatus = .paired(summary)
            self.connectionState = .ready
            return summary
        }
    }

    func cancelOnDevicePairing() {
        onDevicePairing.cancel()
    }

    func startLocationSession(at target: LocationTarget) async {
        await startLocationSession(
            at: target,
            selectedTarget: target,
            historyTarget: target,
            recovery: .fixed(at: target)
        )
    }

    func startWalkingLocationSession(
        at initialTarget: LocationTarget,
        destination: LocationTarget,
        paceMetresPerSecond: Double
    ) async {
        await startLocationSession(
            at: initialTarget,
            selectedTarget: destination,
            historyTarget: destination,
            recovery: .walking(
                from: initialTarget,
                to: destination,
                paceMetresPerSecond: paceMetresPerSecond
            )
        )
    }

    func updateWalkingRouteRecovery(
        from currentLocation: LocationTarget,
        to destination: LocationTarget,
        paceMetresPerSecond: Double
    ) {
        guard var recovery = activeSessionRecovery,
              recovery.kind == .walkingRoute
        else { return }

        let now = Date.now
        recovery.lastReportedLocation = currentLocation
        recovery.destination = destination
        recovery.walkingPaceMetresPerSecond = paceMetresPerSecond
        recovery.updatedAt = now
        activeSessionRecovery = recovery
        selectedTarget = destination
        addToHistory(destination)
        if let data = try? JSONEncoder().encode(recovery) {
            preferences.set(data, forKey: Self.activeSessionRecoveryKey)
            lastRecoverySaveDate = now
        }
    }

    private func startLocationSession(
        at deviceTarget: LocationTarget,
        selectedTarget: LocationTarget,
        historyTarget: LocationTarget,
        recovery: SessionRecoveryRecord
    ) async {
        guard case .paired = pairingStatus else {
            connectionState = .notConfigured
            return
        }

        self.selectedTarget = selectedTarget
        dismissInterruptedSessionRecovery()
        activeSessionRecovery = recovery
        lastRecoverySaveDate = nil
        addToHistory(historyTarget)
        switch deviceSession.updateLocation(deviceTarget) {
        case .updated:
            return
        case .failed:
            return
        case .unavailable:
            break
        }

        do {
            guard let pairingRecord = try await pairingService.pairingRecordData() else {
                activeSessionRecovery = nil
                pairingStatus = .notPaired
                connectionState = .notConfigured
                return
            }
            deviceSession.start(pairingRecord: pairingRecord, target: deviceTarget)
        } catch {
            activeSessionRecovery = nil
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    func restoreRealLocationFromInterruptedSession() async {
        guard let recovery = interruptedSession else { return }
        guard case .paired = pairingStatus else {
            interruptedSessionError = "還原實際位置前，請先配對此 iPhone。"
            return
        }

        interruptedSessionError = nil
        isRestoringInterruptedSession = true
        restorationReachedActiveSession = false
        restorationWasCancelled = false

        do {
            guard let pairingRecord = try await pairingService.pairingRecordData() else {
                isRestoringInterruptedSession = false
                interruptedSessionError = "已儲存的配對紀錄無法使用，請再次配對此 iPhone。"
                return
            }
            deviceSession.start(
                pairingRecord: pairingRecord,
                target: recovery.lastReportedLocation
            )
        } catch {
            isRestoringInterruptedSession = false
            interruptedSessionError = error.localizedDescription
        }
    }

    func cancelInterruptedSessionRestoration() {
        guard isRestoringInterruptedSession else { return }
        restorationWasCancelled = true
        deviceSession.stop()
    }

    func completeInterruptedSessionRestorationAfterMobileData() {
        guard isRestoringInterruptedSession, restorationReachedActiveSession else { return }
        deviceSession.dismissMobileDataGuidance()
        deviceSession.stop()
    }

    func dismissInterruptedSessionRecovery() {
        interruptedSession = nil
        interruptedSessionError = nil
        preferences.removeObject(forKey: Self.activeSessionRecoveryKey)
    }

    func stopLocationSession() {
        isStoppingLocationSessionForRestoration = true
        deviceSession.stop()
    }

    func handleOpenURL(_ url: URL) {
        deviceSession.handleOpenURL(url)
    }

    func removePairingRecord() async {
        onDevicePairing.reset()
        deviceSession.reset()
        do {
            try await pairingService.removeRecord()
            pairingStatus = .notPaired
            connectionState = .notConfigured
        } catch {
            pairingStatus = .failed(message: error.localizedDescription)
            connectionState = .failed(message: error.localizedDescription)
        }
    }

    private func addToHistory(_ target: LocationTarget) {
        locationHistory.removeAll { $0.id == target.id }
        locationHistory.insert(target, at: 0)
        locationHistory = Array(locationHistory.prefix(30))
        save(locationHistory, forKey: Self.historyKey)
    }

    private func applyDeviceSessionPhase(_ phase: DeviceSessionPhase) {
        switch phase {
        case .idle:
            isStoppingLocationSessionForRestoration = false
            if isRestoringInterruptedSession {
                let didRestore = restorationReachedActiveSession && !restorationWasCancelled
                isRestoringInterruptedSession = false
                restorationReachedActiveSession = false
                restorationWasCancelled = false
                if didRestore {
                    dismissInterruptedSessionRecovery()
                }
            }
            clearActiveSessionRecovery()
            if case .paired = pairingStatus {
                connectionState = .ready
            } else {
                connectionState = .notConfigured
            }
        case .openingLocalDevVPN, .discovering, .connecting, .stopping:
            connectionState = .connecting
        case .active(let target):
            connectionState = .active
            isStoppingLocationSessionForRestoration = false
            if isRestoringInterruptedSession {
                restorationReachedActiveSession = true
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(400))
                    guard
                        let self,
                        self.isRestoringInterruptedSession,
                        !self.restorationWasCancelled
                    else { return }
                    if self.deviceSession.mobileDataGuidance != .turnBackOn {
                        self.deviceSession.stop()
                    }
                }
            } else {
                persistActiveSessionRecovery(at: target)
            }
        case .failed(let message):
            connectionState = .failed(message: message)
            if isRestoringInterruptedSession || isStoppingLocationSessionForRestoration {
                let wasRestoringInterruptedSession = isRestoringInterruptedSession
                isRestoringInterruptedSession = false
                restorationReachedActiveSession = false
                restorationWasCancelled = false
                isStoppingLocationSessionForRestoration = false
                if wasRestoringInterruptedSession {
                    interruptedSessionError = message
                }
            } else {
                if deviceSession.lastFailureStage != .locationRestore {
                    clearActiveSessionRecovery()
                }
            }
        }
    }

    private func persistActiveSessionRecovery(at target: LocationTarget) {
        guard var recovery = activeSessionRecovery else { return }
        let now = Date.now

        if
            recovery.kind == .walkingRoute,
            let destination = recovery.destination,
            destination.id == target.id
        {
            recovery = .fixed(at: destination)
        } else {
            recovery.lastReportedLocation = target
            recovery.updatedAt = now
        }
        activeSessionRecovery = recovery

        let shouldSave = lastRecoverySaveDate == nil
            || now.timeIntervalSince(lastRecoverySaveDate ?? .distantPast) >= 5
            || recovery.kind == .fixedLocation
        guard shouldSave, let data = try? JSONEncoder().encode(recovery) else { return }
        preferences.set(data, forKey: Self.activeSessionRecoveryKey)
        lastRecoverySaveDate = now
    }

    private func clearActiveSessionRecovery() {
        guard activeSessionRecovery != nil else { return }
        activeSessionRecovery = nil
        lastRecoverySaveDate = nil
        preferences.removeObject(forKey: Self.activeSessionRecoveryKey)
    }

    private func save(_ locations: [LocationTarget], forKey key: String) {
        guard let data = try? JSONEncoder().encode(locations) else { return }
        preferences.set(data, forKey: key)
    }

    private func save(_ routes: [SavedRoute], forKey key: String) {
        guard let data = try? JSONEncoder().encode(routes) else { return }
        preferences.set(data, forKey: key)
    }

    private static func locations(forKey key: String, in preferences: UserDefaults) -> [LocationTarget] {
        guard
            let data = preferences.data(forKey: key),
            let locations = try? JSONDecoder().decode([LocationTarget].self, from: data)
        else {
            return []
        }
        return locations
    }

    private static func routes(forKey key: String, in preferences: UserDefaults) -> [SavedRoute] {
        guard
            let data = preferences.data(forKey: key),
            let routes = try? JSONDecoder().decode([SavedRoute].self, from: data)
        else {
            return []
        }
        return routes
    }

    private static func recoveryRecord(in preferences: UserDefaults) -> SessionRecoveryRecord? {
        guard
            let data = preferences.data(forKey: Self.activeSessionRecoveryKey),
            let recovery = try? JSONDecoder().decode(SessionRecoveryRecord.self, from: data)
        else { return nil }
        return recovery
    }
}

enum PairingStatus: Equatable {
    case checking
    case importing
    case notPaired
    case paired(PairingRecordSummary)
    case failed(message: String)
}

enum ConnectionState: Equatable {
    case notConfigured
    case ready
    case connecting
    case active
    case failed(message: String)
}
