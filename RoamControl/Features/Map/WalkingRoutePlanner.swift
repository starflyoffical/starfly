import CoreLocation
import MapKit
import Observation

@MainActor
@Observable
final class WalkingRoutePlanner {
    private(set) var route: MKRoute?
    private(set) var importedPolyline: MKPolyline?
    private(set) var destination: LocationTarget?
    private(set) var distance: CLLocationDistance = 0
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    @ObservationIgnored
    private var directions: MKDirections?

    var polyline: MKPolyline? {
        route?.polyline ?? importedPolyline
    }

    var isImportedRoute: Bool {
        importedPolyline != nil
    }

    var routePoints: [RoutePoint] {
        guard let polyline else { return [] }
        let points = polyline.points()
        return (0..<polyline.pointCount).map { RoutePoint(points[$0].coordinate) }
    }

    func preview(to target: LocationTarget, from source: LocationTarget? = nil) async -> MKRoute? {
        directions?.cancel()
        route = nil
        importedPolyline = nil
        destination = target
        distance = 0
        errorMessage = nil
        isLoading = true

        let request = MKDirections.Request()
        if let source {
            request.source = MKMapItem(
                location: CLLocation(latitude: source.latitude, longitude: source.longitude),
                address: nil
            )
        } else {
            request.source = .forCurrentLocation()
        }
        request.destination = MKMapItem(
            location: CLLocation(latitude: target.latitude, longitude: target.longitude),
            address: nil
        )
        request.transportType = .walking
        request.requestsAlternateRoutes = false

        let calculation = MKDirections(request: request)
        directions = calculation

        defer {
            if directions === calculation {
                directions = nil
                isLoading = false
            }
        }

        do {
            let response = try await calculation.calculate()
            guard directions === calculation else { return nil }
            guard let preferredRoute = response.routes.first else {
                errorMessage = "找不到前往此目的地的步行路線。"
                return nil
            }

            route = preferredRoute
            distance = preferredRoute.distance
            return preferredRoute
        } catch is CancellationError {
            return nil
        } catch {
            guard directions === calculation else { return nil }
            errorMessage = "無法取得步行路線。請檢查定位權限與網路連線後再試一次。"
            return nil
        }
    }

    func previewReplacement(to target: LocationTarget, from source: LocationTarget) async -> MKRoute? {
        directions?.cancel()
        errorMessage = nil
        isLoading = true

        let request = MKDirections.Request()
        request.source = MKMapItem(
            location: CLLocation(latitude: source.latitude, longitude: source.longitude),
            address: nil
        )
        request.destination = MKMapItem(
            location: CLLocation(latitude: target.latitude, longitude: target.longitude),
            address: nil
        )
        request.transportType = .walking
        request.requestsAlternateRoutes = false

        let calculation = MKDirections(request: request)
        directions = calculation
        defer {
            if directions === calculation {
                directions = nil
                isLoading = false
            }
        }

        do {
            let response = try await calculation.calculate()
            guard directions === calculation else { return nil }
            guard let replacement = response.routes.first else {
                errorMessage = "找不到前往此目的地的步行路線。"
                return nil
            }
            return replacement
        } catch is CancellationError {
            return nil
        } catch {
            guard directions === calculation else { return nil }
            errorMessage = "無法取得步行路線。請檢查定位權限與網路連線後再試一次。"
            return nil
        }
    }

    func installReplacement(_ route: MKRoute, destination: LocationTarget) {
        directions?.cancel()
        directions = nil
        self.route = route
        importedPolyline = nil
        self.destination = destination
        distance = route.distance
        isLoading = false
        errorMessage = nil
    }

    /// Imports a literal coordinate path. Each non-empty row contains one
    /// latitude/longitude pair, separated by a comma or whitespace.
    @discardableResult
    func importRoute(from text: String) -> Bool {
        directions?.cancel()
        directions = nil
        route = nil
        importedPolyline = nil
        destination = nil
        distance = 0
        errorMessage = nil
        isLoading = false

        var coordinates: [CLLocationCoordinate2D] = []
        let rows = text.split(whereSeparator: { $0.isNewline || $0 == ";" })

        for (index, rawRow) in rows.enumerated() {
            let row = String(rawRow)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "()[]{}"))
            guard !row.isEmpty else { continue }

            let values = row
                .split(whereSeparator: { $0 == "," || $0.isWhitespace })
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            guard
                values.count == 2,
                let latitude = Double(values[0]),
                let longitude = Double(values[1]),
                (-90...90).contains(latitude),
                (-180...180).contains(longitude)
            else {
                errorMessage = "第 \(index + 1) 筆座標格式無效。請使用「緯度, 經度」。"
                return false
            }
            coordinates.append(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        }

        guard coordinates.count >= 2 else {
            errorMessage = "請至少貼上兩筆有效座標，才能建立路徑。"
            return false
        }

        let polyline = coordinates.withUnsafeBufferPointer { buffer in
            MKPolyline(coordinates: buffer.baseAddress!, count: buffer.count)
        }
        importedPolyline = polyline
        distance = polylineLength(of: polyline)
        let last = coordinates[coordinates.count - 1]
        destination = LocationTarget(
            name: "匯入路徑終點",
            subtitle: "共 \(coordinates.count) 個座標點",
            latitude: last.latitude,
            longitude: last.longitude
        )
        return true
    }

    @discardableResult
    func restoreSavedRoute(_ savedRoute: SavedRoute) -> Bool {
        guard savedRoute.points.count >= 2 else {
            errorMessage = "此已儲存路徑沒有足夠的座標點。"
            return false
        }

        directions?.cancel()
        directions = nil
        route = nil
        let coordinates = savedRoute.points.map(\.coordinate)
        importedPolyline = coordinates.withUnsafeBufferPointer { buffer in
            MKPolyline(coordinates: buffer.baseAddress!, count: buffer.count)
        }
        guard let importedPolyline else { return false }
        distance = polylineLength(of: importedPolyline)
        let end = coordinates[coordinates.count - 1]
        destination = LocationTarget(
            name: savedRoute.name,
            subtitle: "已儲存路徑 · \(savedRoute.points.count) 個座標點",
            latitude: end.latitude,
            longitude: end.longitude
        )
        errorMessage = nil
        isLoading = false
        return true
    }

    func clear() {
        directions?.cancel()
        directions = nil
        route = nil
        importedPolyline = nil
        destination = nil
        distance = 0
        isLoading = false
        errorMessage = nil
    }

    func retargetExistingRoute(to target: LocationTarget) {
        guard polyline != nil else { return }
        destination = target
        errorMessage = nil
    }

    private func polylineLength(of polyline: MKPolyline) -> CLLocationDistance {
        guard polyline.pointCount > 1 else { return 0 }
        let points = polyline.points()
        return (1..<polyline.pointCount).reduce(0) { distance, index in
            distance + points[index - 1].distance(to: points[index])
        }
    }
}
