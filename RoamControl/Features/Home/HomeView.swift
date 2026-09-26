import MapKit
import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @State private var mapModel = MapViewModel()
    @State private var walkingRoutePlanner = WalkingRoutePlanner()
    @State private var walkingSimulation = WalkingSimulationController()
    @State private var activeSheet: HomeSheet?
    @State private var shouldRefreshRealLocationWhenActive = false
    @State private var shouldClearLocationAfterRestoration = false
    @State private var isLocatingRealLocationAfterRestoration = false
    @State private var visibleMapCamera: MapCamera?
    @State private var isPreparingRecoveredWalk = false
    @State private var recoveredWalkError: String?
    @State private var pendingRouteDestination: LocationTarget?
    @State private var isConfirmingRouteReplacement = false
    @State private var isChoosingWalkingDestination = false
    @State private var isReroutingWalkingDestination = false
    @State private var walkingDestinationError: String?
    @FocusState private var isSearchFocused: Bool

    init(
        showDeviceSetupInitially: Bool = false,
        showSettingsInitially: Bool = false
    ) {
        _activeSheet = State(
            initialValue: showDeviceSetupInitially
                ? .deviceSetup
                : (showSettingsInitially ? .settings : nil)
        )
    }

    var body: some View {
        ZStack {
            MapReader { proxy in
                Map(position: $mapModel.cameraPosition) {
                    if let route = walkingRoutePlanner.polyline {
                        MapPolyline(route)
                            .stroke(.black, lineWidth: 5)
                    }

                    if shouldShowRealLocation {
                        UserAnnotation()
                    }

                    if let target = mapModel.selectedLocation {
                        Marker(target.name, coordinate: target.coordinate)
                            .tint(.black)
                    }

                    if let coordinate = walkingSimulation.currentCoordinate {
                        Annotation("步行位置", coordinate: coordinate) {
                            Image(systemName: "figure.walk.circle.fill")
                                .font(.title.weight(.semibold))
                                .foregroundStyle(.white, .black)
                                .padding(4)
                                .starFlyGlass(in: Circle())
                                .shadow(color: .black.opacity(0.22), radius: 7, y: 3)
                        }
                    }
                }
                .roamControlMapStyle(appModel.mapDisplayStyle)
                .mapControls {
                    MapScaleView()
                }
                .onMapCameraChange(frequency: .continuous) { context in
                    visibleMapCamera = context.camera
                }
                .onTapGesture { point in
                    if isSearchFocused {
                        isSearchFocused = false
                        return
                    }

                    if isChoosingWalkingDestination && walkingSimulation.locksDestination {
                        guard !isReroutingWalkingDestination else { return }
                        guard let coordinate = proxy.convert(point, from: .local) else { return }
                        Task { await mapModel.selectDroppedPin(at: coordinate) }
                        return
                    }
                    guard !walkingSimulation.locksDestination else { return }
                    guard let coordinate = proxy.convert(point, from: .local) else { return }
                    Task { await mapModel.selectDroppedPin(at: coordinate) }
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 12) {
                if !isSearchingForLocation && !isWalkingRouteActive {
                    StarFlyControlHeader(
                        onConnection: { activeSheet = .deviceSetup },
                        onCoordinateEntry: { activeSheet = .coordinateEntry },
                        onHealthSteps: { activeSheet = .healthSteps },
                        onImportRoute: { activeSheet = .routeImport },
                        onSaved: { activeSheet = .savedPlaces },
                        onSettings: { activeSheet = .settings },
                        isRouteLocked: walkingSimulation.locksDestination && !isChoosingWalkingDestination
                    )
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }

                if !isWalkingRouteActive || isChoosingWalkingDestination {
                    MapSearchBar(
                        query: Binding(
                            get: { mapModel.searchQuery },
                            set: { mapModel.updateSearchQuery($0) }
                        ),
                        isFocused: $isSearchFocused,
                        isSearching: mapModel.isSearching,
                        onSubmit: {
                            Task { await mapModel.search() }
                        },
                        onClear: mapModel.clearSearch
                    )
                    .disabled(isReroutingWalkingDestination
                        || (walkingSimulation.locksDestination && !isChoosingWalkingDestination))
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }

                if mapModel.isShowingSuggestions
                    && !isReroutingWalkingDestination
                    && (!walkingSimulation.locksDestination || isChoosingWalkingDestination) {
                    SearchSuggestionsView(
                        suggestions: mapModel.searchSuggestions,
                        onSelect: { suggestion in
                            isSearchFocused = false
                            Task { await mapModel.selectSuggestion(suggestion) }
                        }
                    )
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    .animation(
                        reduceMotion ? nil : .smooth(duration: 0.24),
                        value: mapModel.isShowingSuggestions
                    )
                }

                if isChoosingWalkingDestination {
                    destinationPickerBanner
                }

                if !isSearchingForLocation {
                    if needsPairingPrompt && mapModel.selectedLocation == nil {
                    Button {
                        activeSheet = .deviceSetup
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "iphone.and.arrow.forward")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)

                            Text("配對 iPhone")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .starFlyGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(StarFlyPressStyle())
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    .animation(
                        reduceMotion ? nil : .smooth(duration: 0.28),
                        value: needsPairingPrompt
                    )
                    }

                    Spacer()

                    HStack(alignment: .bottom) {
                    Spacer()
                    VStack(spacing: 10) {
                        if shouldShowMapCompass {
                            Button(action: resetMapHeading) {
                                CompassRoseDial()
                                    .rotationEffect(.degrees(-normalisedMapHeading))
                                    .frame(width: 48, height: 48)
                                    .starFlyGlass(in: Circle())
                            }
                            .buttonStyle(StarFlyPressStyle())
                            .accessibilityLabel("將地圖轉回正北方向")
                            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                        }

                        if canRequestRealLocation {
                            Button {
                                showCurrentLocationNorthUp()
                            } label: {
                                Group {
                                    if mapModel.isFindingRealLocation {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "location.fill")
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(.primary)
                                    }
                                }
                                .frame(width: 48, height: 48)
                                .starFlyGlass(in: Circle())
                            }
                            .buttonStyle(StarFlyPressStyle())
                            .disabled(mapModel.isFindingRealLocation)
                            .accessibilityLabel("顯示我的目前位置")
                        }
                    }
                    }

                    Group {
                    if isLocatingRealLocationAfterRestoration {
                    RestoringRealLocationCard()
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    } else if walkingRoutePlanner.polyline != nil,
                   let destination = walkingRoutePlanner.destination {
                    WalkingRoutePreviewCard(
                        routeDistance: walkingRoutePlanner.distance,
                        routePoints: walkingRoutePlanner.routePoints,
                        destination: walkingSimulation.destination ?? destination,
                        simulation: walkingSimulation,
                        isPaired: isPaired,
                        isRouteSaved: isCurrentRouteSaved,
                        onStart: {
                            Task { await walkingSimulation.start(using: appModel) }
                        },
                        onTogglePause: walkingSimulation.togglePause,
                        onWalkBack: {
                            guard let returnTarget = walkingSimulation.prepareReturnTrip() else { return }
                            walkingRoutePlanner.retargetExistingRoute(to: returnTarget)
                            mapModel.show(returnTarget)
                        },
                        onChooseNewLocation: {
                            walkingSimulation.reset()
                            walkingRoutePlanner.clear()
                            mapModel.clearSelectedLocation()
                        },
                        onChangeDestination: {
                            guard walkingSimulation.phase == .walking || walkingSimulation.phase == .paused else {
                                walkingSimulation.reset()
                                walkingRoutePlanner.clear()
                                mapModel.clearSelectedLocation()
                                return
                            }
                            walkingDestinationError = nil
                            isChoosingWalkingDestination = true
                            mapModel.clearSelectedLocation()
                            mapModel.clearSearch()
                        },
                        onSaveRoute: saveCurrentRoute,
                        onFinishKeepingPosition: {
                            finishWalkingKeepingPosition(fallback: destination)
                        },
                        onFinishRestoringPosition: {
                            shouldClearLocationAfterRestoration = true
                            appModel.stopLocationSession()
                        },
                        onDone: {
                            finishWalkingKeepingPosition(fallback: destination)
                        }
                    )
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    } else {
                    LocationSelectionCard(
                        location: mapModel.selectedLocation,
                        isFavourite: mapModel.selectedLocation.map(appModel.isFavourite) ?? false,
                        isPaired: isPaired,
                        sessionPhase: appModel.deviceSession.phase,
                        localDevVPNInstallURL: appModel.localDevVPNInstallURL,
                        isPreviewingWalkingRoute: walkingRoutePlanner.isLoading,
                        walkingRouteError: walkingRoutePlanner.errorMessage,
                        onToggleFavourite: {
                            guard let target = mapModel.selectedLocation else { return }
                            appModel.toggleFavourite(target)
                        },
                        onClearSelection: {
                            walkingSimulation.reset()
                            walkingRoutePlanner.clear()
                            mapModel.clearSelectedLocation()
                        },
                        onPreviewWalkingRoute: {
                            guard let target = mapModel.selectedLocation else { return }
                            Task {
                                if let route = await walkingRoutePlanner.preview(to: target) {
                                    walkingSimulation.prepare(route: route, destination: target)
                                    mapModel.show(route)
                                }
                            }
                        },
                        onStart: {
                            guard let target = mapModel.selectedLocation else { return }
                            shouldRefreshRealLocationWhenActive = false
                            mapModel.show(target)
                            Task { await appModel.startLocationSession(at: target) }
                        },
                        onStop: {
                            shouldClearLocationAfterRestoration = true
                            appModel.stopLocationSession()
                        }
                    )
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    }
                    }
                    .animation(
                        reduceMotion ? nil : .smooth(duration: 0.28),
                        value: walkingRoutePlanner.polyline != nil
                    )
                    .animation(
                        reduceMotion ? nil : .smooth(duration: 0.28),
                        value: mapModel.selectedLocation?.id
                    )
                    .animation(
                        reduceMotion ? nil : .smooth(duration: 0.28),
                        value: isLocatingRealLocationAfterRestoration
                    )
                } else {
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, isWalkingRouteActive && isChoosingWalkingDestination ? 150 : 8)
            .padding(.bottom, 10)
            .animation(
                reduceMotion ? nil : .smooth(duration: 0.28),
                value: isSearchingForLocation
            )
            .animation(
                reduceMotion ? nil : .smooth(duration: 0.28),
                value: isWalkingRouteActive
            )

            if let message = mapModel.errorMessage {
                VStack {
                    Spacer()
                    Text(message)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.red, in: Capsule())
                        .padding(.bottom, 196)
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }

            if let guidance = appModel.deviceSession.mobileDataGuidance {
                Color.black.opacity(0.34)
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    MobileDataGuidanceView(
                        guidance: guidance,
                        onOpenLocalDevVPN: appModel.deviceSession.openLocalDevVPN,
                        onRetry: appModel.deviceSession.retryConnection,
                        onUseMobileData: appModel.deviceSession.useMobileDataGuidance,
                        onMobileDataOff: appModel.deviceSession.confirmMobileDataIsOff,
                        onRunNetworkShortcut: runNetworkShortcut,
                        onCancel: appModel.stopLocationSession,
                        onDone: {
                            if appModel.isRestoringInterruptedSession {
                                appModel.completeInterruptedSessionRestorationAfterMobileData()
                            } else {
                                appModel.deviceSession.dismissMobileDataGuidance()
                            }
                        }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                .zIndex(10)
            }

            if
                let recovery = appModel.interruptedSession,
                appModel.deviceSession.mobileDataGuidance == nil
            {
                Color.black.opacity(0.34)
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    SessionRecoveryView(
                        recovery: recovery,
                        isPaired: isPaired,
                        isResuming: isPreparingRecoveredWalk,
                        isRestoring: appModel.isRestoringInterruptedSession,
                        errorMessage: recoveredWalkError ?? appModel.interruptedSessionError,
                        onResume: {
                            resumeInterruptedSession(recovery)
                        },
                        onRestore: {
                            recoveredWalkError = nil
                            walkingSimulation.reset()
                            walkingRoutePlanner.clear()
                            Task { await appModel.restoreRealLocationFromInterruptedSession() }
                        },
                        onAlreadyRestored: {
                            dismissInterruptedSessionRecovery()
                        },
                        onCancel: {
                            if appModel.isRestoringInterruptedSession {
                                appModel.cancelInterruptedSessionRestoration()
                            }
                        }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                .zIndex(9)
            }
        }
        .task {
            await appModel.restorePairingStatus()
            if let interruptedLocation = appModel.interruptedSession?.lastReportedLocation {
                mapModel.center(on: interruptedLocation)
            }
            mapModel.prepareCurrentLocation(
                recenter: appModel.interruptedSession == nil
            )
            if activeSheet == .deviceSetup {
                appModel.deviceSetupWasPresented()
            }
        }
        .onChange(of: appModel.deviceSession.phase) { oldPhase, newPhase in
            walkingSimulation.handleDeviceSessionPhase(
                newPhase,
                deviceSession: appModel.deviceSession
            )

            switch newPhase {
            case .openingLocalDevVPN, .discovering, .connecting, .active, .stopping:
                shouldRefreshRealLocationWhenActive = false
                mapModel.invalidateRealLocationCache()
            case .idle:
                if oldPhase == .stopping, shouldClearLocationAfterRestoration {
                    shouldClearLocationAfterRestoration = false
                    walkingSimulation.reset()
                    walkingRoutePlanner.clear()
                    mapModel.clearSelectedLocation()
                    shouldRefreshRealLocationWhenActive = false
                    isLocatingRealLocationAfterRestoration = true
                    mapModel.refreshRealLocationAfterRestoration()
                }
            case .failed:
                shouldClearLocationAfterRestoration = false
            }

            guard oldPhase == .stopping, newPhase == .idle else { return }
            guard !isLocatingRealLocationAfterRestoration else { return }
            shouldRefreshRealLocationWhenActive = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                guard shouldRefreshRealLocationWhenActive, scenePhase == .active else { return }
                shouldRefreshRealLocationWhenActive = false
                guard case .idle = appModel.deviceSession.phase else { return }
                mapModel.showRealLocationAfterSession()
            }
        }
        .onChange(of: mapModel.selectedLocation?.id) { _, selectedLocationID in
            if isChoosingWalkingDestination,
               walkingSimulation.locksDestination,
               let selectedLocationID,
               walkingSimulation.destination?.id != selectedLocationID,
               let selected = mapModel.selectedLocation {
                isSearchFocused = false
                beginWalkingDestinationReplacement(with: selected)
                return
            }
            guard !walkingSimulation.locksDestination else { return }
            guard let destination = walkingRoutePlanner.destination else { return }
            guard let selectedLocationID else { return }
            guard destination.id != selectedLocationID, let selected = mapModel.selectedLocation else { return }
            pendingRouteDestination = selected
            isConfirmingRouteReplacement = true
        }
        .confirmationDialog(
            "要改用新的目的地嗎？",
            isPresented: $isConfirmingRouteReplacement,
            titleVisibility: .visible
        ) {
            Button("重新規劃路徑") {
                replaceRouteDestination()
            }
            Button("保留目前路徑", role: .cancel) {
                if let destination = walkingRoutePlanner.destination {
                    mapModel.show(destination)
                }
                pendingRouteDestination = nil
            }
        } message: {
            Text("目前已預覽一條路徑。改用新目的地會以新位置重新規劃，原本的路徑仍可先收藏。")
        }
        .onChange(of: mapModel.isFindingRealLocation) { _, isFindingRealLocation in
            guard isLocatingRealLocationAfterRestoration, !isFindingRealLocation else { return }
            isLocatingRealLocationAfterRestoration = false
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            appModel.deviceSession.appDidBecomeActive()

            guard shouldRefreshRealLocationWhenActive else { return }
            shouldRefreshRealLocationWhenActive = false
            guard case .idle = appModel.deviceSession.phase else { return }
            mapModel.showRealLocationAfterSession()
        }
        .onChange(of: activeSheet) { _, sheet in
            if sheet == .deviceSetup {
                appModel.deviceSetupWasPresented()
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .deviceSetup:
                PairingSetupView()
                    .environment(appModel)
            case .settings:
                SettingsView()
                    .environment(appModel)
            case .healthSteps:
                NavigationStack {
                    HealthStepsView()
                }
            case .savedPlaces:
                SavedPlacesView(
                    favourites: appModel.favouriteLocations,
                    routes: appModel.favouriteRoutes,
                    history: appModel.locationHistory,
                    shouldShowFavouriteReorderHint: !appModel.hasSeenFavouriteReorderHint,
                    isFavourite: appModel.isFavourite,
                    onSelect: { target in
                        guard !walkingSimulation.locksDestination else { return }
                        mapModel.show(target)
                    },
                    onToggleFavourite: appModel.toggleFavourite,
                    onDeleteFavourite: appModel.removeFavourite,
                    onMoveFavourites: appModel.moveFavouriteLocations,
                    onDismissFavouriteReorderHint: appModel.dismissFavouriteReorderHint,
                    onRenameFavourite: appModel.renameFavourite,
                    onDeleteHistory: appModel.removeFromHistory,
                    onClearFavourites: appModel.clearFavouriteLocations,
                    onSelectRoute: { savedRoute in
                        guard !walkingSimulation.locksDestination,
                              walkingRoutePlanner.restoreSavedRoute(savedRoute),
                              let polyline = walkingRoutePlanner.polyline,
                              let destination = walkingRoutePlanner.destination
                        else { return }
                        walkingSimulation.prepare(
                            polyline: polyline,
                            destination: destination,
                            supportsWaypointNavigation: true
                        )
                        walkingSimulation.loopCount = savedRoute.loopCount
                        walkingSimulation.repeatsIndefinitely = savedRoute.repeatsIndefinitely
                        walkingSimulation.traversalStyle = savedRoute.traversalStyle
                        walkingSimulation.waypointHoldSeconds = savedRoute.waypointHoldSeconds
                        walkingSimulation.sendsRouteNotifications = savedRoute.sendsRouteNotifications
                        mapModel.clearSelectedLocation()
                        mapModel.show(polyline)
                    },
                    onDeleteRoute: appModel.removeFavouriteRoute,
                    onClearRoutes: appModel.clearFavouriteRoutes,
                    onClearHistory: appModel.clearLocationHistory
                )
            case .routeImport:
                RouteImportView { text, loopCount, repeatsIndefinitely, traversalStyle, waypointHoldSeconds, sendsNotifications in
                    guard walkingRoutePlanner.importRoute(from: text) else {
                        return walkingRoutePlanner.errorMessage ?? "無法建立路徑。"
                    }
                    guard let polyline = walkingRoutePlanner.polyline,
                          let destination = walkingRoutePlanner.destination
                    else {
                        return "無法建立路徑。"
                    }

                    walkingSimulation.prepare(
                        polyline: polyline,
                        destination: destination,
                        supportsWaypointNavigation: true
                    )
                    walkingSimulation.loopCount = loopCount
                    walkingSimulation.repeatsIndefinitely = repeatsIndefinitely
                    walkingSimulation.traversalStyle = traversalStyle
                    walkingSimulation.waypointHoldSeconds = waypointHoldSeconds
                    walkingSimulation.sendsRouteNotifications = sendsNotifications
                    mapModel.clearSelectedLocation()
                    mapModel.show(polyline)
                    return nil
                }
            case .coordinateEntry:
                CoordinateEntryView { target in
                    if walkingSimulation.locksDestination {
                        isChoosingWalkingDestination = true
                        walkingDestinationError = nil
                        mapModel.show(target)
                        return
                    }
                    walkingSimulation.reset()
                    walkingRoutePlanner.clear()
                    mapModel.show(target)
                }
            }
        }
    }

    private var needsPairingPrompt: Bool {
        switch appModel.pairingStatus {
        case .notPaired, .failed:
            true
        case .checking, .importing, .paired:
            false
        }
    }

    private var isCurrentRouteSaved: Bool {
        let points = walkingRoutePlanner.routePoints
        guard !points.isEmpty else { return false }
        return appModel.favouriteRoutes.contains { $0.points == points }
    }

    private func saveCurrentRoute() {
        let points = walkingRoutePlanner.routePoints
        guard !points.isEmpty, let destination = walkingRoutePlanner.destination else { return }
        appModel.saveRoute(
            SavedRoute(
                name: "\(destination.name) 路徑",
                points: points,
                loopCount: walkingSimulation.loopCount,
                repeatsIndefinitely: walkingSimulation.repeatsIndefinitely,
                traversalStyle: walkingSimulation.traversalStyle,
                waypointHoldSeconds: walkingSimulation.waypointHoldSeconds,
                sendsRouteNotifications: walkingSimulation.sendsRouteNotifications
            )
        )
    }

    private func replaceRouteDestination() {
        guard let target = pendingRouteDestination else { return }
        pendingRouteDestination = nil
        walkingSimulation.reset()
        walkingRoutePlanner.clear()
        Task { @MainActor in
            guard let route = await walkingRoutePlanner.preview(to: target) else { return }
            walkingSimulation.prepare(route: route, destination: target)
            mapModel.show(route)
        }
    }

    private var destinationPickerBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(isReroutingWalkingDestination ? "正在規劃新目的地…" : "選擇新目的地")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                if isReroutingWalkingDestination {
                    ProgressView().controlSize(.small)
                }
            }

            if let walkingDestinationError {
                Text(walkingDestinationError)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if !isReroutingWalkingDestination {
                Text("搜尋地點、貼上座標，或點選地圖；目前路徑會接續前進。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button {
                    activeSheet = .coordinateEntry
                } label: {
                    Label("貼入座標", systemImage: "location.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isReroutingWalkingDestination)

                Button("取消") {
                    isChoosingWalkingDestination = false
                    walkingDestinationError = nil
                    mapModel.clearSelectedLocation()
                    if let destination = walkingSimulation.destination {
                        mapModel.show(destination)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isReroutingWalkingDestination)
            }
        }
        .padding(14)
        .starFlyGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func finishWalkingKeepingPosition(fallback: LocationTarget) {
        let heldCoordinate = walkingSimulation.currentCoordinate
        walkingSimulation.finishKeepingCurrentLocation(using: appModel.deviceSession)
        walkingSimulation.reset()
        walkingRoutePlanner.clear()

        if let heldCoordinate {
            mapModel.show(
                LocationTarget(
                    name: "保留的位置",
                    subtitle: "路徑結束時保留的模擬位置",
                    latitude: heldCoordinate.latitude,
                    longitude: heldCoordinate.longitude
                )
            )
        } else {
            mapModel.show(fallback)
        }
    }

    private func beginWalkingDestinationReplacement(with target: LocationTarget) {
        guard !isReroutingWalkingDestination,
              let coordinate = walkingSimulation.currentCoordinate,
              walkingSimulation.phase == .walking || walkingSimulation.phase == .paused
        else { return }

        let wasWalking = walkingSimulation.phase == .walking
        if wasWalking { walkingSimulation.togglePause() }
        isReroutingWalkingDestination = true
        walkingDestinationError = nil

        let currentLocation = LocationTarget(
            name: "目前位置",
            subtitle: "路徑中途改道起點",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        Task { @MainActor in
            let replacement = await walkingRoutePlanner.previewReplacement(
                to: target,
                from: currentLocation
            )
            guard let replacement else {
                walkingDestinationError = walkingRoutePlanner.errorMessage
                    ?? "無法規劃新路線，請再選一次目的地。"
                isReroutingWalkingDestination = false
                if wasWalking, walkingSimulation.phase == .paused {
                    walkingSimulation.togglePause()
                }
                return
            }

            walkingRoutePlanner.installReplacement(replacement, destination: target)
            walkingSimulation.replaceCurrentRoute(
                with: replacement,
                destination: target,
                using: appModel.deviceSession
            )
            if wasWalking { walkingSimulation.togglePause() }
            appModel.updateWalkingRouteRecovery(
                from: currentLocation,
                to: target,
                paceMetresPerSecond: walkingSimulation.paceMetresPerSecond
            )
            mapModel.show(replacement)
            isChoosingWalkingDestination = false
            isReroutingWalkingDestination = false
            walkingDestinationError = nil
        }
    }

    private var isSearchingForLocation: Bool {
        isSearchFocused || mapModel.isShowingSuggestions || isChoosingWalkingDestination
    }

    private var isWalkingRouteActive: Bool {
        walkingSimulation.phase == .walking || walkingSimulation.phase == .paused
    }

    private var isPaired: Bool {
        if case .paired = appModel.pairingStatus {
            return true
        }
        return false
    }

    private var shouldShowRealLocation: Bool {
        switch appModel.deviceSession.phase {
        case .active, .stopping:
            false
        case .idle, .openingLocalDevVPN, .discovering, .connecting, .failed:
            true
        }
    }

    private var canRequestRealLocation: Bool {
        switch appModel.deviceSession.phase {
        case .idle, .failed:
            true
        case .openingLocalDevVPN, .discovering, .connecting, .active, .stopping:
            false
        }
    }

    private var isLocationSessionActive: Bool {
        if case .active = appModel.deviceSession.phase { return true }
        return false
    }

    private func runNetworkShortcut(_ command: StarFlyShortcut.NetworkCommand) {
        let name = UserDefaults.standard.string(forKey: "starfly.networkShortcutName")
            ?? StarFlyShortcut.defaultNetworkWorkflowName
        guard let url = StarFlyShortcut.runURL(named: name, command: command) else { return }
        openURL(url)
    }

    private var normalisedMapHeading: Double {
        guard let heading = visibleMapCamera?.heading else { return 0 }
        let remainder = heading.truncatingRemainder(dividingBy: 360)
        return remainder >= 0 ? remainder : remainder + 360
    }

    private var shouldShowMapCompass: Bool {
        let heading = normalisedMapHeading
        return min(heading, 360 - heading) > 1
    }

    private func resetMapHeading() {
        guard let camera = visibleMapCamera else { return }
        let northUpCamera = MapCamera(
            centerCoordinate: camera.centerCoordinate,
            distance: camera.distance,
            heading: 0,
            pitch: camera.pitch
        )

        if reduceMotion {
            mapModel.cameraPosition = .camera(northUpCamera)
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                mapModel.cameraPosition = .camera(northUpCamera)
            }
        }
    }

    private func showCurrentLocationNorthUp() {
        if reduceMotion {
            mapModel.showCurrentLocation()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                mapModel.showCurrentLocation()
            }
        }
    }

    private func resumeInterruptedSession(_ recovery: SessionRecoveryRecord) {
        recoveredWalkError = nil

        guard recovery.isWalkingRoute, let destination = recovery.destination else {
            appModel.dismissInterruptedSessionRecovery()
            mapModel.show(recovery.lastReportedLocation)
            Task { await appModel.startLocationSession(at: recovery.lastReportedLocation) }
            return
        }

        isPreparingRecoveredWalk = true
        Task { @MainActor in
            let route = await walkingRoutePlanner.preview(
                to: destination,
                from: recovery.lastReportedLocation
            )
            guard let route else {
                recoveredWalkError = walkingRoutePlanner.errorMessage
                    ?? "無法準備剩餘的步行路線。"
                isPreparingRecoveredWalk = false
                return
            }

            appModel.dismissInterruptedSessionRecovery()
            walkingSimulation.prepare(route: route, destination: destination)
            if let rawPace = recovery.walkingPaceMetresPerSecond {
                walkingSimulation.paceMetresPerSecond = min(
                    max(rawPace, WalkingSimulationController.minimumSpeedMetresPerSecond),
                    WalkingSimulationController.maximumSpeedMetresPerSecond
                )
            }
            mapModel.show(route)
            isPreparingRecoveredWalk = false
            await walkingSimulation.start(using: appModel)
        }
    }

    private func dismissInterruptedSessionRecovery() {
        recoveredWalkError = nil
        isPreparingRecoveredWalk = false
        walkingSimulation.reset()
        walkingRoutePlanner.clear()
        appModel.dismissInterruptedSessionRecovery()
        mapModel.showRealLocationAfterSession()
    }
}

private enum HomeSheet: String, Identifiable, Equatable {
    case deviceSetup
    case settings
    case healthSteps
    case savedPlaces
    case routeImport
    case coordinateEntry

    var id: String { rawValue }
}

private struct CompassRoseDial: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.primary.opacity(0.06))

            Circle()
                .strokeBorder(.primary.opacity(0.28), lineWidth: 0.8)

            Text("北")
                .foregroundStyle(.red)
                .offset(y: -10.5)

            Text("東")
                .offset(x: 10.5)

            Text("南")
                .offset(y: 10.5)

            Text("西")
                .offset(x: -10.5)

            Circle()
                .fill(.primary.opacity(0.65))
                .frame(width: 3, height: 3)
        }
        .font(.system(size: 7.5, weight: .bold, design: .rounded))
        .foregroundStyle(.primary.opacity(0.78))
        .frame(width: 34, height: 34)
    }
}

private extension View {
    @ViewBuilder
    func roamControlMapStyle(_ style: MapDisplayStyle) -> some View {
        switch style {
        case .standard:
            mapStyle(.standard(elevation: .realistic))
        case .satellite:
            mapStyle(.imagery(elevation: .realistic))
        case .hybrid:
            mapStyle(.hybrid(elevation: .realistic))
        }
    }
}

#Preview {
    HomeView()
        .environment(AppModel())
}
