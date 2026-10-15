import SwiftUI

/// Recipes from the app ranked by how much of them you can make with what you have.
///
/// When nothing in the recipe book can be made from these ingredients alone, Chef AI leads:
/// it can suggest dishes that use exactly what you have, instead of recipes that need shopping.
struct MatchesView: View {
    @Environment(RecipeLibrary.self) private var library
    @Environment(AccountStore.self) private var accounts
    let ingredients: [String]

    var body: some View {
        let matches = RecipeMatcher.matches(for: library.recipes.filter(accounts.shows), have: ingredients)
        let ready = matches.filter(\.canMakeNow)
        let almost = matches.filter { !$0.canMakeNow }

        List {
            if ready.isEmpty {
                Section {
                    chefCard(title: "Cook with exactly what you have",
                             detail: "None of our recipes use only these ingredients. Chef AI can suggest dishes that do.")
                }
            } else {
                Section {
                    ForEach(ready) { MatchRow(match: $0) }
                } header: {
                    Text("Cook now: you have everything")
                }
                Section {
                    chefCard(title: "More ideas from Chef AI",
                             detail: "Dishes made from what you have, beyond our recipe book")
                }
            }
            if !almost.isEmpty {
                Section {
                    ForEach(almost) { MatchRow(match: $0) }
                } header: {
                    Text("With a quick trip to the store")
                } footer: {
                    Text("Pantry staples like salt, oil and flour are assumed.")
                }
            }
        }
        .navigationTitle("Recipes for you")
        .navigationDestination(for: Recipe.self) { RecipeDetailView(recipe: $0) }
    }

    private func chefCard(title: String, detail: String) -> some View {
        NavigationLink(value: ChefRoute.ideas(ingredients)) {
            HStack(spacing: Theme.Space.m) {
                Image(systemName: "sparkles")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.accentColor.gradient, in: .rect(cornerRadius: Theme.Radius.small))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, Theme.Space.xs)
        }
    }
}

private struct MatchRow: View {
    let match: RecipeMatch

    var body: some View {
        NavigationLink(value: match.recipe) {
            HStack(spacing: 14) {
                RecipePhoto(recipe: match.recipe, emojiSize: 26)
                    .frame(width: 60, height: 60)
                    .clipShape(.rect(cornerRadius: Theme.Radius.small))
                VStack(alignment: .leading, spacing: 4) {
                    Text(match.recipe.name)
                        .font(.headline)
                    Text("You have \(match.have.count) of \(match.have.count + match.missing.count) · \(match.recipe.minutes) min")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !match.missing.isEmpty {
                        Text("Need: " + match.missing.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }
}
