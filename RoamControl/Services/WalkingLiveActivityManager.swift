import ActivityKit
import Foundation
import OSLog

@MainActor
final class WalkingLiveActivityManager {
    static let shared = WalkingLiveActivityManager()

    private var activity: Activity<StarFlyWalkingActivityAttributes>?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.starfly.app", category: "LiveActivities")

    private init() {}

    func updateOrStart(_ state: StarFlyWalkingActivityAttributes.ContentState) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.warning("Live Activities are disabled in iOS settings; route status will not appear on the Lock Screen or Dynamic Island.")
            return
        }

        if let existing = activity ?? Activity<StarFlyWalkingActivityAttributes>.activities.first {
            activity = existing
            await existing.update(ActivityContent(state: state, staleDate: Date.now.addingTimeInterval(90)))
            return
        }

        do {
            activity = try Activity.request(
                attributes: StarFlyWalkingActivityAttributes(startedAt: .now),
                content: ActivityContent(state: state, staleDate: Date.now.addingTimeInterval(90)),
                pushType: nil
            )
        } catch {
            logger.error("Could not start the route Live Activity: \(error.localizedDescription, privacy: .public)")
        }
    }

    func end(with state: StarFlyWalkingActivityAttributes.ContentState) async {
        guard let existing = activity ?? Activity<StarFlyWalkingActivityAttributes>.activities.first else {
            return
        }
        await existing.end(
            ActivityContent(state: state, staleDate: nil),
            dismissalPolicy: .after(Date.now.addingTimeInterval(45))
        )
        activity = nil
    }
}
