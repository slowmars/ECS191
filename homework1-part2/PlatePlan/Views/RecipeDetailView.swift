import SwiftUI

/// A recipe from the library. The main actions live in a bar at the bottom of the screen,
/// right under the thumb (Fitts's law), and stay visible while scrolling.
struct RecipeDetailView: View {
    @Environment(RecipeLibrary.self) private var library
    @Environment(MealPlan.self) private var plan
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    @State private var localServings: Int?
    @State private var cooking = false

    /// In the plan, servings edit the plan (and the shopping list). Otherwise it's a preview.
    private var servings: Binding<Int> {
        Binding(
            get: { plan.servings(for: recipe) ?? localServings ?? recipe.servings },
            set: { newValue in
                if plan.contains(recipe) {
                    plan.setServings(newValue, for: recipe)
                } else {
                    localServings = newValue
                }
            }
        )
    }

    var body: some View {
        ScrollView {
            RecipeBody(recipe: recipe, servings: servings)
        }
        .ignoresSafeArea(edges: .top)
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) { actionBar }
        // The action bar replaces the tab bar here, so the page gets the full height.
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if recipe.isCustom && library.isSaved(recipe) {
                Menu("More", systemImage: "ellipsis") {
                    Button("Delete recipe", systemImage: "trash", role: .destructive) {
                        plan.remove(recipe)
                        library.deleteSaved(recipe)
                        dismiss()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $cooking) {
            CookingView(recipe: recipe, servings: servings.wrappedValue)
        }
    }

    /// The primary (filled) button is always the next sensible step:
    /// "Add to plan" until it's planned, then "Cook".
    private var actionBar: some View {
        let planned = plan.contains(recipe)
        return HStack(spacing: Theme.Space.m) {
            Button {
                withAnimation(.snappy) {
                    planned ? plan.remove(recipe) : plan.add(recipe, servings: servings.wrappedValue)
                }
            } label: {
                Label(planned ? "Planned" : "Add to plan", systemImage: planned ? "checkmark" : "plus")
                    .frame(maxWidth: .infinity)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(ProminenceStyle(prominent: !planned))
            .accessibilityHint(planned ? "Removes it from your plan" : "")
            .sensoryFeedback(.success, trigger: planned) { _, isPlanned in isPlanned }

            Button {
                cooking = true
            } label: {
                Label("Cook", systemImage: "flame.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ProminenceStyle(prominent: planned))
        }
        .controlSize(.large)
        .padding(.horizontal, Theme.Space.l)
        .padding(.vertical, Theme.Space.m)
        .background(.bar)
        .animation(.snappy, value: planned)
    }
}

/// Filled for the primary action, outlined for the secondary one.
struct ProminenceStyle: PrimitiveButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        if prominent {
            Button(role: configuration.role, action: configuration.trigger) { configuration.label }
                .buttonStyle(.borderedProminent)
        } else {
            Button(role: configuration.role, action: configuration.trigger) { configuration.label }
                .buttonStyle(.bordered)
        }
    }
}
