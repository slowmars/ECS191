import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

@main
struct PlatePlanWidgets: WidgetBundle {
    var body: some Widget {
        CookingTimerLiveActivity()
    }
}

/// The cooking timer on the Lock Screen and in the Dynamic Island.
struct CookingTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<CookingTimerMetadata>.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "frying.pan.fill")
                    .font(.title2)
                    .foregroundStyle(context.attributes.tintColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.metadata?.recipeName ?? "Cooking timer")
                        .font(.headline)
                        .lineLimit(1)
                    Text("Step \(context.attributes.metadata?.stepNumber ?? 1)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                remaining(context.state)
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold).monospacedDigit())
                    .foregroundStyle(context.attributes.tintColor)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Step \(context.attributes.metadata?.stepNumber ?? 1)", systemImage: "frying.pan.fill")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    remaining(context.state)
                        .font(.system(.title, design: .rounded, weight: .semibold).monospacedDigit())
                        .foregroundStyle(context.attributes.tintColor)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.metadata?.recipeName ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "frying.pan.fill").foregroundStyle(context.attributes.tintColor)
            } compactTrailing: {
                remaining(context.state)
                    .monospacedDigit()
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(context.attributes.tintColor)
            }
        }
    }

    @ViewBuilder
    private func remaining(_ state: AlarmPresentationState) -> some View {
        switch state.mode {
        case .countdown(let countdown):
            Text(timerInterval: Date.now...max(Date.now, countdown.fireDate), countsDown: true)
                .multilineTextAlignment(.trailing)
        case .paused(let paused):
            Text(Duration.seconds(paused.totalCountdownDuration - paused.previouslyElapsedDuration),
                 format: .time(pattern: .minuteSecond))
        default:
            Text("Done")
        }
    }
}
