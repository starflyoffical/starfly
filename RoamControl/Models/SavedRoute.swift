import CoreLocation
import Foundation

struct RoutePoint: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    init(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct SavedRoute: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var name: String
    let points: [RoutePoint]
    var loopCount: Int
    var repeatsIndefinitely: Bool
    var traversalStyle: RouteTraversalStyle
    var waypointHoldSeconds: TimeInterval
    var sendsRouteNotifications: Bool
    let savedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        points: [RoutePoint],
        loopCount: Int,
        repeatsIndefinitely: Bool,
        traversalStyle: RouteTraversalStyle = .continuous,
        waypointHoldSeconds: TimeInterval = 3,
        sendsRouteNotifications: Bool = true,
        savedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.points = points
        self.loopCount = max(1, loopCount)
        self.repeatsIndefinitely = repeatsIndefinitely
        self.traversalStyle = traversalStyle
        self.waypointHoldSeconds = max(0, waypointHoldSeconds)
        self.sendsRouteNotifications = sendsRouteNotifications
        self.savedAt = savedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, points, loopCount, repeatsIndefinitely
        case traversalStyle, waypointHoldSeconds, sendsRouteNotifications, savedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        points = try container.decode([RoutePoint].self, forKey: .points)
        loopCount = max(1, try container.decode(Int.self, forKey: .loopCount))
        repeatsIndefinitely = try container.decode(Bool.self, forKey: .repeatsIndefinitely)
        traversalStyle = try container.decodeIfPresent(RouteTraversalStyle.self, forKey: .traversalStyle) ?? .continuous
        waypointHoldSeconds = max(0, try container.decodeIfPresent(TimeInterval.self, forKey: .waypointHoldSeconds) ?? 3)
        sendsRouteNotifications = try container.decodeIfPresent(Bool.self, forKey: .sendsRouteNotifications) ?? true
        savedAt = try container.decode(Date.self, forKey: .savedAt)
    }
}
