import SwiftUI
import WidgetKit

@main
struct StarFlyLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        StarFlyWalkingLiveActivity()
    }
}

struct StarFlyWalkingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StarFlyWalkingActivityAttributes.self) { context in
            lockScreenActivity(context)
                .activityBackgroundTint(Color.black.opacity(0.92))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "starfly://route"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image("StarFlyBrand")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .clipShape(Circle())
                            Text(context.state.status)
                                .font(.caption2.weight(.medium))
                                .lineLimit(1)
                                .foregroundStyle(.white.opacity(0.62))
                        }
                        Text(context.state.destinationName)
                            .font(.headline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .truncationMode(.tail)
                            .foregroundStyle(.white)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(context.state.speedKilometresPerHour, format: .number.precision(.fractionLength(1)))
                            .font(.title3.monospacedDigit().weight(.semibold))
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(.white)
                        Text("km/h")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.64))
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 7) {
                        ProgressView(value: context.state.progress)
                            .tint(.white)
                        HStack(spacing: 6) {
                            if context.state.supportsWaypointNavigation == true {
                                Button(intent: PreviousRouteWaypointIntent()) {
                                    Image(systemName: "chevron.backward")
                                        .font(.caption.weight(.bold))
                                        .frame(width: 26, height: 26)
                                        .background(.white.opacity(0.12), in: Circle())
                                }
                                .buttonStyle(.plain)
                                .disabled((context.state.waypointIndex ?? 1) <= 1)
                                .accessibilityLabel(Text(context.state.previousWaypointTitle ?? "上一個路徑點"))

                                Text("\(context.state.waypointIndex ?? 1)/\(context.state.waypointCount ?? 1)")
                                    .font(.caption2.monospacedDigit().weight(.semibold))
                                    .frame(minWidth: 30)
                                    .accessibilityLabel("路徑點")

                                Button(intent: NextRouteWaypointIntent()) {
                                    Image(systemName: "chevron.forward")
                                        .font(.caption.weight(.bold))
                                        .frame(width: 26, height: 26)
                                        .background(.white.opacity(0.12), in: Circle())
                                }
                                .buttonStyle(.plain)
                                .disabled((context.state.waypointIndex ?? 1) >= (context.state.waypointCount ?? 1))
                                .accessibilityLabel(Text(context.state.nextWaypointTitle ?? "下一個路徑點"))
                            } else {
                                Text("\(Int((context.state.progress * 100).rounded()))%")
                                    .font(.caption2.monospacedDigit().weight(.semibold))
                            }

                            Spacer(minLength: 4)

                            if context.state.pauseEnabled != false {
                                Button(intent: ToggleWalkingPauseIntent()) {
                                    Image(systemName: context.state.isPaused == true ? "play.fill" : "pause.fill")
                                        .font(.caption.weight(.bold))
                                        .frame(width: 29, height: 29)
                                        .background(.white.opacity(0.12), in: Circle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text(context.state.pauseTitle ?? "暫停步行"))
                            }

                            Button(intent: DecreaseWalkingSpeedIntent()) {
                                Image(systemName: "minus")
                                    .font(.caption.weight(.bold))
                                    .frame(width: 27, height: 27)
                                    .background(.white.opacity(0.12), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .disabled(context.state.speedAdjustmentEnabled == false
                                || context.state.speedKilometresPerHour <= 1.8)
                            .accessibilityLabel(Text(context.state.decreaseSpeedTitle ?? "降低速度"))

                            Button(intent: IncreaseWalkingSpeedIntent()) {
                                Image(systemName: "plus")
                                    .font(.caption.weight(.bold))
                                    .frame(width: 27, height: 27)
                                    .background(.white.opacity(0.12), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .disabled(context.state.speedAdjustmentEnabled == false
                                || context.state.speedKilometresPerHour >= 72)
                            .accessibilityLabel(Text(context.state.increaseSpeedTitle ?? "提高速度"))
                        }
                        .foregroundStyle(.white.opacity(0.74))
                    }
                    .padding(.top, 1)
                }
            } compactLeading: {
                Image(systemName: "figure.walk")
                    .foregroundStyle(.white)
            } compactTrailing: {
                Text(Int(context.state.speedKilometresPerHour.rounded()).formatted())
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "figure.walk")
                    .foregroundStyle(.white)
            }
            .keylineTint(.white.opacity(0.82))
            .widgetURL(URL(string: "starfly://route"))
        }
    }

    private func lockScreenActivity(
        _ context: ActivityViewContext<StarFlyWalkingActivityAttributes>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "figure.walk.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 3) {
                    Text(context.state.status)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.64))
                    Text(context.state.destinationName)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(context.state.speedKilometresPerHour, format: .number.precision(.fractionLength(1)))
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                    Text("km/h")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.64))
                }
            }

            ProgressView(value: context.state.progress)
                .tint(.white)

            HStack {
                Text(context.state.remainingDistanceDescription)
                Spacer()
                Text(context.state.estimatedArrival, style: .time)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white.opacity(0.7))
        }
        .padding(16)
    }

}
