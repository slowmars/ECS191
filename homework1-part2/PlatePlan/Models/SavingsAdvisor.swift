import Foundation

/// A meal worth adding because it uses up food you'd otherwise throw away.
struct SavingsSuggestion: Identifiable, Hashable, Sendable {
    let recipe: Recipe
    /// The serving count that uses leftovers best (it may differ from the recipe's default).
    let servings: Int
    /// Leftover ingredients from the current plan that this recipe uses.
    let uses: [String]
    /// How much more the trip costs with this recipe added (used for ranking only).
    let addedCost: Double
    /// New items this recipe adds to the shopping list.
    let extraItems: [String]
    /// How much less food goes to waste.
    let wasteSaved: Double
    var id: String { recipe.id }

    var addedCostPerServing: Double { addedCost / Double(max(servings, 1)) }
}

/// Finds the cheapest extra meals that soak up the plan's perishable leftovers.
///
/// For every recipe not already planned that uses at least one leftover, it rebuilds the shopping
/// list with that recipe added, at several serving sizes, and measures two things: what the trip
/// costs extra, and how much less perishable food is left to spoil. Trying different serving sizes
/// matters: a parfait for 1 opens a new tub of berries and wastes most of it, while a parfait for 4
/// finishes the berries *and* the leftover yogurt.
/// Meals are ranked by the money that's really new per serving (extra cost minus waste avoided),
/// so meals made mostly from leftovers rise to the top.
enum SavingsAdvisor {
    static func suggestions(for plan: ShoppingList.Plan, candidates: [Recipe], catalog: IngredientCatalog,
                            isAtHome: @escaping (String, Bool) -> Bool, limit: Int = 3) -> [SavingsSuggestion] {
        let base = ShoppingList.build(from: plan, catalog: catalog, isAtHome: isAtHome)
        guard base.wasteValue >= 0.5 else { return [] }

        let planned = Set(plan.map(\.recipe.id))
        let leftoverNames = Set(base.leftovers.map(\.id))

        let suggestions = candidates.compactMap { candidate -> SavingsSuggestion? in
            guard !planned.contains(candidate.id) else { return nil }
            let uses = candidate.ingredients.map(\.name).filter { leftoverNames.contains($0.lowercased()) }
            guard !uses.isEmpty else { return nil }

            let options = servingOptions(for: candidate).compactMap { servings -> SavingsSuggestion? in
                let report = ShoppingList.build(from: plan + [(candidate, servings)], catalog: catalog,
                                                isAtHome: isAtHome)
                let wasteSaved = base.wasteValue - report.wasteValue
                guard wasteSaved >= 0.5 else { return nil }
                let alreadyBuying = Set(base.toBuy.map(\.id))
                return SavingsSuggestion(recipe: candidate, servings: servings, uses: uses,
                                         addedCost: report.totalCost - base.totalCost,
                                         extraItems: report.toBuy.filter { !alreadyBuying.contains($0.id) }.map(\.name),
                                         wasteSaved: wasteSaved)
            }
            return options.min(by: isBetter)
        }

        return suggestions
            .sorted(by: isBetter)
            .prefix(limit)
            .map { $0 }
    }

    /// Net new money per serving: what you'd pay extra, minus the food you'd no longer throw away.
    private static func netCost(_ suggestion: SavingsSuggestion) -> Double {
        (suggestion.addedCost - suggestion.wasteSaved) / Double(max(suggestion.servings, 1))
    }

    /// Lower net cost per serving wins (compared to the cent); on a tie, saving more food wins.
    private static func isBetter(_ a: SavingsSuggestion, _ b: SavingsSuggestion) -> Bool {
        let costA = (netCost(a) * 100).rounded(), costB = (netCost(b) * 100).rounded()
        return costA != costB ? costA < costB : a.wasteSaved > b.wasteSaved
    }

    /// Serving sizes worth trying: from 1 up to double the recipe, capped so batch recipes
    /// (24 cookies) don't explode the search.
    private static func servingOptions(for recipe: Recipe) -> [Int] {
        let upper = min(max(recipe.servings * 2, 4), 12)
        return Array(1...upper)
    }
}
