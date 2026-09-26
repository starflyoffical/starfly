import CoreLocation
import Foundation
import Observation

enum BackgroundKeepAliveStatus: String, Sendable {
    case idle, awaitingAuthorization, starting, receivingUpdates, denied, restricted
    case servicesDisabled, missingBackgroundMode, locationUnavailable, failed, stopped
}

/// Receives updates solely to maintain an active session. Coordinates are never
/// stored, injected, or transmitted. DVT remains the simulation source.
@MainActor
@Observable
final class BackgroundLocationKeepAlive: NSObject, @preconcurrency CLLocationManagerDelegate {
    private(set) var status: BackgroundKeepAliveStatus = .idle
    private(set) var started = false
    private let manager: CLLocationManager
    private var requested = false
    private let hasBackgroundMode: Bool

    init(manager: CLLocationManager = CLLocationManager(),
         hasBackgroundMode: Bool = (Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String])?.contains("location") == true) {
        self.manager = manager
        self.hasBackgroundMode = hasBackgroundMode
        super.init()
        // Created on the main actor: Core Location delivers delegates on this run loop.
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
    }

    func start() {
        guard !requested else { return }
        requested = true
        reconcileAuthorization()
    }

    func stop() {
        guard requested || started else { return }
        requested = false
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        update(.stopped, started: false)
    }

    private func update(_ status: BackgroundKeepAliveStatus, started: Bool) {
        guard self.status != status || self.started != started else { return }
        self.status = status
        self.started = started
    }

    private func unavailable(_ status: BackgroundKeepAliveStatus) {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        update(status, started: false)
    }

    private func reconcileAuthorization() {
        guard requested else { return }
        guard hasBackgroundMode else { unavailable(.missingBackgroundMode); return }
        switch manager.authorizationStatus {
        case .notDetermined:
            update(.awaitingAuthorization, started: false)
            manager.requestWhenInUseAuthorization()
        case .denied:
            unavailable(CLLocationManager.locationServicesEnabled() ? .denied : .servicesDisabled)
        case .restricted:
            unavailable(.restricted)
        case .authorizedAlways, .authorizedWhenInUse:
            guard !started else { return }
            manager.allowsBackgroundLocationUpdates = true
            manager.startUpdatingLocation()
            // A request is not proof of delivery; the first callback is separate.
            update(.starting, started: true)
        @unknown default:
            unavailable(.failed)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        reconcileAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard requested, started, !locations.isEmpty else { return }
        update(.receivingUpdates, started: true)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard requested else { return }
        if (error as? CLError)?.code == .locationUnknown {
            // Transient loss of a fix does not stop the location service.
            update(.locationUnavailable, started: started)
        } else if (error as? CLError)?.code == .denied {
            unavailable(CLLocationManager.locationServicesEnabled() ? .denied : .servicesDisabled)
        } else {
            unavailable(.failed)
        }
    }
}
