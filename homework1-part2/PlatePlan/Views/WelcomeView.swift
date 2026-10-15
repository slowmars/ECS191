import SwiftUI

/// Shown once, on first launch. Three steps explain the whole app at a glance,
/// then one button gets out of the way.
struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Theme.Space.xxl) {
            Spacer(minLength: Theme.Space.l)
            VStack(spacing: Theme.Space.m) {
                Text("🍽️")
                    .font(.system(size: 72))
                    .accessibilityHidden(true)
                Text("Welcome to Cookd")
                    .font(Theme.heading(.largeTitle))
                    .multilineTextAlignment(.center)
                Text("Healthy home cooking without the planning headache.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                feature("book.fill", "Pick a few recipes", "58 simple, balanced dishes from around the world.")
                feature("cart.fill", "Get one shopping list", "Everything combined, sized to real packages and sorted by aisle.")
                feature("flame.fill", "Cook step by step", "Big steps, built-in timers, and the screen stays on.")
                feature("sparkles", "Ask Chef AI", "Snap your fridge for ideas, or ask for any dish.")
            }
            .padding(.horizontal, Theme.Space.s)

            Spacer(minLength: Theme.Space.l)

            Button {
                dismiss()
            } label: {
                Text("Get started").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(Theme.Space.xl)
        .interactiveDismissDisabled(false)
    }

    private func feature(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.l) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
