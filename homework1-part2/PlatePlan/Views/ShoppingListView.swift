import SwiftUI

/// The shopping list, built for use in a store: big rows, one tap to tick, aisles in walking order,
/// and items that stay put when ticked so nothing jumps under your thumb.
struct ShoppingListView: View {
    @Environment(MealPlan.self) private var plan
    @Environment(Router.self) private var router
    let report: ShoppingReport

    var body: some View {
        let toBuy = report.toBuy
        let done = toBuy.count { plan.isChecked($0) }

        NavigationStack {
            Group {
                if report.isEmpty {
                    EmptyState(systemImage: "cart",
                               title: "Nothing to buy yet",
                               message: "Add recipes to your plan. Every ingredient lands here, combined and sorted by aisle.",
                               actionTitle: "Browse recipes") { router.tab = .recipes }
                } else {
                    List {
                        Section { progress(done: done, of: toBuy.count) }

                        if report.wasteValue >= 0.5 {
                            Section {
                                NavigationLink {
                                    UseItUpView(report: report)
                                } label: {
                                    Label {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Use up your leftovers").font(.headline)
                                            Text("Meals that finish what you're buying")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    } icon: {
                                        Image(systemName: "leaf.arrow.triangle.circlepath").foregroundStyle(.tint)
                                    }
                                }
                            }
                        }

                        ForEach(report.sections) { section in
                            Section {
                                ForEach(section.items) { row($0) }
                            } header: {
                                Label(section.aisle, systemImage: Self.icon(for: section.aisle))
                            }
                        }

                        if !report.atHome.isEmpty {
                            Section {
                                ForEach(report.atHome) { atHomeRow($0) }
                            } header: {
                                Label("Already at home", systemImage: "house")
                            } footer: {
                                Text("Pantry staples are assumed. Swipe left on any item to move it between lists.")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Shopping")
            .navigationDestination(for: Recipe.self) { RecipeDetailView(recipe: $0) }
            .toolbar {
                if !report.isEmpty {
                    ShareLink(item: ShoppingList.plainText(report))
                    Menu("More", systemImage: "ellipsis") {
                        Button("Uncheck all", systemImage: "arrow.uturn.backward") { plan.uncheckAll() }
                            .disabled(plan.checkedItems.isEmpty)
                    }
                }
            }
        }
    }

    private func progress(done: Int, of total: Int) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(done == total ? "All done!" : "\(total - done) left")
                    .font(Theme.heading(.title))
                    .contentTransition(.numericText())
                Spacer()
                Text("\(done) of \(total) in cart")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(done), total: Double(max(total, 1)))
        }
        .padding(.vertical, Theme.Space.xs)
        .animation(.snappy, value: done)
    }

    private func row(_ item: ShoppingItem) -> some View {
        let checked = plan.isChecked(item)
        return Button {
            withAnimation(.snappy) { plan.toggleChecked(item) }
        } label: {
            HStack(alignment: .center, spacing: Theme.Space.m) {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(checked ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body.weight(.medium))
                        .strikethrough(checked)
                    Text(purchaseLine(item))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .opacity(checked ? 0.5 : 1)
            .padding(.vertical, Theme.Space.xs)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: checked)
        .accessibilityLabel(item.name)
        .accessibilityValue(checked ? "In cart" : purchaseLine(item))
        .accessibilityAddTraits(checked ? .isSelected : [])
        .swipeActions {
            Button("Have it", systemImage: "house") {
                withAnimation { plan.setAtHome(true, for: item) }
            }
            .tint(.indigo)
        }
    }

    /// "Buy 1 dozen · need 3" or "Buy 8 oz bag (2 cups) · ½ cup left over"
    private func purchaseLine(_ item: ShoppingItem) -> String {
        guard let purchase = item.purchase else { return item.amountText.isEmpty ? "As needed" : item.amountText }
        var parts = ["Buy \(purchase.text)"]
        if !item.amountText.isEmpty, purchase.text != item.amountText, !purchase.text.contains(item.amountText) {
            parts.append("need \(item.amountText)")
        }
        // Only food that spoils is worth flagging; extra rice or spices just stay in the pantry.
        if item.perishable, let leftover = purchase.leftoverText {
            parts.append("\(leftover) left over")
        }
        return parts.joined(separator: " · ")
    }

    private func atHomeRow(_ item: ShoppingItem) -> some View {
        HStack {
            Text(item.name)
            Spacer()
            Text(item.amountText.isEmpty ? "to taste" : item.amountText)
                .foregroundStyle(.secondary)
        }
        .swipeActions {
            Button("Need it", systemImage: "cart.badge.plus") {
                withAnimation { plan.setAtHome(false, for: item) }
            }
            .tint(.accentColor)
        }
    }

    static func icon(for aisle: String) -> String {
        switch aisle {
        case "Produce": "carrot"
        case "Meat & Seafood": "fish"
        case "Dairy & Eggs": "cup.and.saucer"
        case "Bakery & Tortillas": "birthday.cake"
        case "Pasta, Rice & Grains": "takeoutbag.and.cup.and.straw"
        case "Canned & Jarred": "cylinder"
        case "Condiments & Sauces": "drop"
        case "Spices & Baking": "sparkles"
        case "Frozen": "snowflake"
        default: "basket"
        }
    }
}

/// Leftovers that could go bad, and meals that would use them up.
/// Lives on its own screen so the list itself stays focused on shopping (Hick's law).
private struct UseItUpView: View {
    @Environment(RecipeLibrary.self) private var library
    @Environment(MealPlan.self) private var plan
    let report: ShoppingReport
    /// Worked out in the background: it rebuilds the shopping list many times, which is too slow
    /// for the main thread. nil until the first answer arrives.
    @State private var suggestions: [SavingsSuggestion]?

    private struct Inputs: Equatable {
        let entries: [MealPlan.Entry]
        let pantry: [String: Bool]
    }

    var body: some View {
        List {
            Section("You'll have left over") {
                ForEach(report.leftovers) { item in
                    HStack {
                        Text(item.name)
                        Spacer()
                        Text(item.purchase?.leftoverText ?? "")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                if suggestions == nil {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if suggestions?.isEmpty == true {
                    Text("No recipe uses these up without leaving new leftovers. Try freezing what you can.")
                        .foregroundStyle(.secondary)
                }
                ForEach(suggestions ?? []) { suggestion in
                    HStack(spacing: Theme.Space.m) {
                        NavigationLink(value: suggestion.recipe) {
                            RecipeThumbnailRow(recipe: suggestion.recipe, subtitle: detail(suggestion)) { EmptyView() }
                        }
                        Button {
                            withAnimation { plan.add(suggestion.recipe, servings: suggestion.servings) }
                        } label: {
                            Image(systemName: plan.contains(suggestion.recipe) ? "checkmark.circle.fill" : "plus.circle.fill")
                                .font(.title2)
                                .frame(width: Theme.minTap, height: Theme.minTap)
                        }
                        .buttonStyle(.borderless)
                        .disabled(plan.contains(suggestion.recipe))
                        .accessibilityLabel("Add \(suggestion.recipe.name) to plan")
                    }
                }
            } header: {
                Text("Meals that use them")
            } footer: {
                Text("Each idea is sized to finish as much of your leftovers as possible.")
            }
        }
        .navigationTitle("Use it up")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: Inputs(entries: plan.entries, pantry: plan.pantry)) {
            let planned = plan.planned(in: library)
            let candidates = library.bundled, catalog = library.catalog, pantry = plan.pantry
            let found = await Task.detached(priority: .userInitiated) {
                SavingsAdvisor.suggestions(for: planned, candidates: candidates, catalog: catalog) { name, isStaple in
                    pantry[name.lowercased()] ?? isStaple
                }
            }.value
            withAnimation { suggestions = found }
        }
    }

    private func detail(_ suggestion: SavingsSuggestion) -> String {
        let uses = "Uses your " + suggestion.uses.map { $0.prefix(1).lowercased() + $0.dropFirst() }.joined(separator: ", ")
        let extra = suggestion.extraItems.isEmpty ? "nothing new to buy"
            : "\(suggestion.extraItems.count) new item\(suggestion.extraItems.count == 1 ? "" : "s")"
        return "\(uses) · \(suggestion.servings) servings · \(extra)"
    }
}
