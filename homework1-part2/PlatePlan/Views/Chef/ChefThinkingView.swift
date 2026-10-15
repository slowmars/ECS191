import SwiftUI

/// Chef AI's waiting state: a gently pulsing sparkle while short status lines show
/// what the chef is doing, so the wait feels alive instead of being a countdown.
struct ChefThinkingView: View {
    let title: String
    /// Shown one after another; the last one stays until the answer arrives.
    var steps: [String] = []

    var body: some View {
        VStack(spacing: Theme.Space.xl) {
            PulsingSparkle()
                .frame(width: 140, height: 140)
            VStack(spacing: Theme.Space.s) {
                Text(title)
                    .font(Theme.heading(.title3))
                    .multilineTextAlignment(.center)
                if !steps.isEmpty { StatusTicker(steps: steps) }
            }
        }
        .padding(Theme.Space.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// A large sparkle on a softly breathing circle.
struct PulsingSparkle: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let pulse = reduceMotion ? 0 : sin(context.date.timeIntervalSince(start) * 2.4)
            ZStack {
                Circle()
                    .fill(.tint.opacity(0.10))
                    .frame(width: 104, height: 104)
                    .scaleEffect(1 + 0.08 * pulse)
                Image(systemName: "sparkles")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(.tint)
                    .scaleEffect(1 + 0.06 * pulse)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}

/// Status lines that change every few seconds and stop on the last one.
private struct StatusTicker: View {
    let steps: [String]
    @State private var index = 0

    var body: some View {
        Text(steps[index])
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .id(index)
            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .move(edge: .top).combined(with: .opacity)))
            .task {
                while index < steps.count - 1 {
                    try? await Task.sleep(for: .seconds(3.5))
                    guard !Task.isCancelled else { return }
                    withAnimation(.snappy) { index += 1 }
                }
            }
    }
}

#Preview {
    ChefThinkingView(title: "Writing a recipe for pad thai…",
                     steps: ["Looking up well-loved versions…", "Balancing the nutrition…"])
}
