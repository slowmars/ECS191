import SwiftUI

/// This week's meals. Cooking is one tap away on every row, and finished meals move
/// to a "Cooked" section so progress is visible (goal-gradient effect).
struct PlanView: View {
    @Environment(RecipeLibrary.self) private var library
    @Environment(MealPlan.self) private var plan
    @Environment(Router.self) private var router
    @State private var confirmingClear = false
    @State private var cooking: Recipe?

    var body: some View {
        let planned = plan.planned(in: library)
        let toCook = planned.filter { !plan.isCooked($0.recipe) }
        let cooked = planned.filter { plan.isCooked($0.recipe) }

        NavigationStack {
            Group {
                if planned.isEmpty {
                    EmptyState(systemImage: "fork.knife",
                               title: "Your week is wide open",
                               message: "Tap + on any recipe to add it here. Your shopping list builds itself.",
                               actionTitle: "Browse recipes") { router.tab = .recipes }
                } else {
                    List {
                        Section { summary(total: planned.count, cooked: cooked.count) }

                        if !toCook.isEmpty {
                            Section("To cook") {
                                ForEach(toCook, id: \.recipe.id) { row($0.recipe, servings: $0.servings) }
                            }
                        }
                        if !cooked.isEmpty {
                            Section("Cooked") {
                                ForEach(cooked, id: \.recipe.id) { row($0.recipe, servings: $0.servings) }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("My Plan")
            .navigationDestination(for: Recipe.self) { RecipeDetailView(recipe: $0) }
            .toolbar {
                if !planned.isEmpty {
                    Menu("Edit", systemImage: "ellipsis") {
                        Button("Remove cooked meals", systemImage: "checkmark.circle") {
                            withAnimation { cooked.forEach { plan.remove($0.recipe) } }
                        }
                        .disabled(cooked.isEmpty)
                        Button("Start a new plan", systemImage: "trash", role: .destructive) { confirmingClear = true }
                    }
                }
            }
            .confirmationDialog("Start a new plan?", isPresented: $confirmingClear, titleVisibility: .visible) {
                Button("Remove all meals", role: .destructive) { withAnimation { plan.clear() } }
            } message: {
                Text("This also clears your shopping list.")
            }
            .fullScreenCover(item: $cooking) { recipe in
                CookingView(recipe: recipe, servings: plan.servings(for: recipe) ?? recipe.servings)
            }
        }
    }

    private func summary(total: Int, cooked: Int) -> some View {
        let report = plan.shoppingReport(in: library)
        let itemsLeft = report.toBuy.count { !plan.isChecked($0) }
        return VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(cooked) of \(total)")
                    .font(Theme.heading(.title))
                    .contentTransition(.numericText())
                Text("meals cooked")
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(cooked), total: Double(max(total, 1)))
            Button {
                router.tab = .shopping
            } label: {
                Label(itemsLeft == 0 ? "Shopping done" : "\(itemsLeft) item\(itemsLeft == 1 ? "" : "s") to buy",
                      systemImage: "cart")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, Theme.Space.xs)
        .accessibilityElement(children: .contain)
    }

    private func row(_ recipe: Recipe, servings: Int) -> some View {
        let isCooked = plan.isCooked(recipe)
        return NavigationLink(value: recipe) {
            RecipeThumbnailRow(recipe: recipe,
                               subtitle: "\(servings) serving\(servings == 1 ? "" : "s") · \(recipe.minutes) min") {
                if !isCooked {
                    Button {
                        cooking = recipe
                    } label: {
                        Label("Cook", systemImage: "flame.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .fixedSize()
                    .accessibilityLabel("Cook \(recipe.name)")
                }
            }
            .opacity(isCooked ? 0.6 : 1)
        }
        .swipeActions(edge: .trailing) {
            Button("Remove", systemImage: "trash", role: .destructive) {
                withAnimation { plan.remove(recipe) }
            }
        }
        .swipeActions(edge: .leading) {
            Button(isCooked ? "Not cooked" : "Cooked", systemImage: isCooked ? "arrow.uturn.backward" : "checkmark") {
                withAnimation { plan.setCooked(!isCooked, for: recipe) }
            }
            .tint(.accentColor)
        }
        .contextMenu {
            Button(isCooked ? "Mark as not cooked" : "Mark as cooked", systemImage: "checkmark.circle") {
                withAnimation { plan.setCooked(!isCooked, for: recipe) }
            }
            Button("Remove from plan", systemImage: "trash", role: .destructive) {
                withAnimation { plan.remove(recipe) }
            }
        }
    }
}
