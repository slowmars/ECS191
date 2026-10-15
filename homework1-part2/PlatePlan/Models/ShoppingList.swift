import Foundation

/// One line on the shopping list: an ingredient merged across every planned recipe.
struct ShoppingItem: Identifiable, Hashable, Sendable {
    /// Lowercased ingredient name.
    let id: String
    let name: String
    let aisle: String
    let isStaple: Bool
    let perishable: Bool
    /// What the recipes need in total, e.g. "1¼ cups". Empty for "to taste" items.
    let amountText: String
    let recipeNames: [String]
    /// What to buy and what it costs. nil for items the catalog doesn't know (some AI recipes).
    let purchase: Purchase?
    /// You said you already have it (pantry staples are assumed).
    let isAtHome: Bool

    /// Changes when the needed amount changes, so a ticked item un-ticks
    /// if you add another recipe that needs more of it.
    var checkKey: String { id + "|" + amountText }
}

struct ShoppingSection: Identifiable, Hashable, Sendable {
    let aisle: String
    let items: [ShoppingItem]
    var id: String { aisle }
}

/// Everything the shopping tab shows: what to buy, what it costs and what might go to waste.
struct ShoppingReport: Sendable {
    /// Items to buy, grouped by aisle in store order.
    let sections: [ShoppingSection]
    /// Items you already have.
    let atHome: [ShoppingItem]
    let totalCost: Double
    /// Items to buy that couldn't be priced.
    let unpricedCount: Int
    let servings: Int
    /// Perishable food you'll buy but not use: the money that could go in the trash.
    let wasteValue: Double
    let leftovers: [ShoppingItem]
    /// Long-lasting things you'll buy more of than you need (a jar of cumin, a bag of rice).
    /// That money isn't lost; it stocks the pantry for next time.
    let pantryValue: Double

    var toBuy: [ShoppingItem] { sections.flatMap(\.items) }
    /// What the planned meals themselves use.
    var mealsValue: Double { max(0, totalCost - pantryValue - wasteValue) }
    /// Cost per serving, not counting what stays in the pantry (waste is a real cost, so it's included).
    var costPerServing: Double { servings > 0 ? (totalCost - pantryValue) / Double(servings) : 0 }
    var isEmpty: Bool { sections.isEmpty && atHome.isEmpty }
}

enum ShoppingList {
    typealias Plan = [(recipe: Recipe, servings: Int)]

    /// - Parameter isAtHome: whether the user already has an ingredient (lowercased name, is staple).
    static func build(from plan: Plan, catalog: IngredientCatalog,
                      isAtHome: (String, Bool) -> Bool = { _, isStaple in isStaple }) -> ShoppingReport {
        var order: [String] = []
        var first: [String: Ingredient] = [:]
        var amounts: [String: [Amount]] = [:]
        var recipeNames: [String: [String]] = [:]

        for (recipe, servings) in plan {
            let factor = Double(servings) / Double(max(recipe.servings, 1))
            for ingredient in recipe.ingredients {
                let key = ingredient.name.lowercased()
                if first[key] == nil {
                    order.append(key)
                    first[key] = ingredient
                }
                if let amount = ingredient.amount(scaledBy: factor) {
                    amounts[key, default: []].append(amount)
                }
                if recipeNames[key]?.contains(recipe.name) != true {
                    recipeNames[key, default: []].append(recipe.name)
                }
            }
        }

        let items = order.compactMap { key -> ShoppingItem? in
            guard let ingredient = first[key] else { return nil }
            let catalogItem = catalog.item(named: key)
            let isStaple = catalogItem?.isStaple ?? ingredient.isStaple
            let aisle = catalogItem?.aisle ?? (Aisle.all.contains(ingredient.aisle) ? ingredient.aisle : Aisle.other)
            let needs = amounts[key] ?? []
            return ShoppingItem(
                id: key,
                name: catalogItem?.name ?? ingredient.name,
                aisle: aisle,
                isStaple: isStaple,
                perishable: catalogItem?.perishable ?? false,
                amountText: Amount.total(needs),
                recipeNames: recipeNames[key] ?? [],
                purchase: catalog.purchase(of: key, for: needs),
                isAtHome: isAtHome(key, isStaple)
            )
        }

        let toBuy = items.filter { !$0.isAtHome }
        let aisleOrder = Aisle.all + [Aisle.other]
        let byAisle = Dictionary(grouping: toBuy, by: \.aisle)
        let sections = aisleOrder.compactMap { aisle -> ShoppingSection? in
            guard let items = byAisle[aisle] else { return nil }
            return ShoppingSection(aisle: aisle, items: items.sorted { $0.name < $1.name })
        }
        let leftovers = toBuy.filter { $0.perishable && $0.purchase?.leftoverText != nil }

        return ShoppingReport(
            sections: sections,
            atHome: items.filter(\.isAtHome).sorted { $0.name < $1.name },
            totalCost: toBuy.reduce(0) { $0 + ($1.purchase?.cost ?? 0) },
            unpricedCount: toBuy.count { $0.purchase == nil },
            servings: plan.reduce(0) { $0 + $1.servings },
            wasteValue: leftovers.reduce(0) { $0 + ($1.purchase?.leftoverValue ?? 0) },
            leftovers: leftovers,
            pantryValue: toBuy.filter { !$0.perishable }.reduce(0) { $0 + ($1.purchase?.leftoverValue ?? 0) }
        )
    }

    /// Plain-text version for sharing (Messages, Notes, etc.).
    static func plainText(_ report: ShoppingReport) -> String {
        var lines = ["Shopping list"]
        for section in report.sections {
            lines.append("")
            lines.append(section.aisle.uppercased())
            for item in section.items {
                let detail = item.purchase?.text ?? item.amountText
                lines.append(detail.isEmpty ? "• \(item.name)" : "• \(item.name) — \(detail)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
