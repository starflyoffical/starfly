import AppIntents
import Foundation

extension Notification.Name {
    static let starFlyLiveActivityWaypointNavigation = Notification.Name(
        "StarFly.LiveActivity.WaypointNavigation"
    )
    static let starFlyLiveActivitySpeedAdjustment = Notification.Name(
        "StarFly.LiveActivity.SpeedAdjustment"
    )
    static let starFlyLiveActivityPauseToggle = Notification.Name(
        "StarFly.LiveActivity.PauseToggle"
    )
}

struct PreviousRouteWaypointIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Previous StarFly route point"
    static var description = IntentDescription("Move the active route to its previous coordinate.")

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .starFlyLiveActivityWaypointNavigation,
            object: nil,
            userInfo: ["offset": -1]
        )
        return .result()
    }
}

struct NextRouteWaypointIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Next StarFly route point"
    static var description = IntentDescription("Move the active route to its next coordinate.")

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .starFlyLiveActivityWaypointNavigation,
            object: nil,
            userInfo: ["offset": 1]
        )
        return .result()
    }
}

struct DecreaseWalkingSpeedIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Decrease StarFly walking speed"
    static var description = IntentDescription("Lower the active route speed by 1 km/h.")

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .starFlyLiveActivitySpeedAdjustment,
            object: nil,
            userInfo: ["deltaKilometresPerHour": -1.0]
        )
        return .result()
    }
}

struct IncreaseWalkingSpeedIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Increase StarFly walking speed"
    static var description = IntentDescription("Raise the active route speed by 1 km/h.")

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .starFlyLiveActivitySpeedAdjustment,
            object: nil,
            userInfo: ["deltaKilometresPerHour": 1.0]
        )
        return .result()
    }
}

struct ToggleWalkingPauseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause or resume StarFly walking"
    static var description = IntentDescription("Pause or resume the active StarFly walking route.")

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .starFlyLiveActivityPauseToggle, object: nil)
        return .result()
    }
}
