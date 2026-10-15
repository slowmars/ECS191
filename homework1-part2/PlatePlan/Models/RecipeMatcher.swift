import Foundation

/// How well a recipe fits the ingredients someone already has.
struct RecipeMatch: Identifiable, Hashable, Sendable {
    let recipe: Recipe
    let have: [String]
    let missing: [String]
    var id: String { recipe.id }

    var canMakeNow: Bool { missing.isEmpty }
}

enum RecipeMatcher {
    /// Ranks recipes by how few ingredients you'd still need to buy.
    /// Pantry staples (salt, oil, flour...) are assumed to be on hand.
    static func matches(for recipes: [Recipe], have available: [String], maxMissing: Int = 3) -> [RecipeMatch] {
        let availableTokens = available.map(tokens)
        return recipes
            .compactMap { recipe -> RecipeMatch? in
                var have: [String] = []
                var missing: [String] = []
                for ingredient in recipe.shoppingIngredients {
                    let needed = tokens(ingredient.name)
                    if availableTokens.contains(where: { isSameIngredient($0, needed) }) {
                        have.append(ingredient.name)
                    } else {
                        missing.append(ingredient.name)
                    }
                }
                guard !have.isEmpty, missing.count <= maxMissing else { return nil }
                return RecipeMatch(recipe: recipe, have: have, missing: missing)
            }
            .sorted {
                ($0.missing.count, -$0.have.count, $0.recipe.name) < ($1.missing.count, -$1.have.count, $1.recipe.name)
            }
    }

    /// "cheddar" matches "Shredded cheddar"; "chicken breasts" matches "Chicken breast".
    static func isSameIngredient(_ a: Set<String>, _ b: Set<String>) -> Bool {
        guard !a.isEmpty, !b.isEmpty else { return false }
        return a.isSubset(of: b) || b.isSubset(of: a)
    }

    private static let ignoredWords: Set<String> = ["fresh", "large", "small", "whole", "of", "and", "the", "a"]

    static func tokens(_ name: String) -> Set<String> {
        Set(
            name.lowercased()
                .split { !$0.isLetter }
                .map { singular(String($0)) }
                .filter { !ignoredWords.contains($0) }
        )
    }

    private static func singular(_ word: String) -> String {
        if word.hasSuffix("oes") { return String(word.dropLast(2)) }      // tomatoes → tomato
        if word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" } // berries → berry
        if word.hasSuffix("s") && !word.hasSuffix("ss") && word.count > 3 { return String(word.dropLast()) }
        return word
    }
}
