import ActivityKit
import Foundation

struct StarFlyWalkingActivityAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        var destinationName: String
        var speedKilometresPerHour: Double
        var progress: Double
        var remainingDistanceMetres: Double
        var remainingDistanceDescription: String
        var estimatedArrival: Date
        var status: String
        var supportsWaypointNavigation: Bool?
        var waypointIndex: Int?
        var waypointCount: Int?
        var previousWaypointTitle: String?
        var nextWaypointTitle: String?
        var decreaseSpeedTitle: String?
        var increaseSpeedTitle: String?
        var speedAdjustmentEnabled: Bool?
        var pauseTitle: String?
        var isPaused: Bool?
        var pauseEnabled: Bool?
    }

    var startedAt: Date
}
