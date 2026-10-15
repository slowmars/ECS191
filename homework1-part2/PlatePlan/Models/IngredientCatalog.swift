import Foundation

/// How an ingredient is sold at a typical US supermarket, with an estimated price.
/// Built by Scripts/build_recipes.py into Resources/ingredients.json.
struct CatalogItem: Codable, Hashable, Sendable {
    enum SoldBy: String, Codable, Sendable {
        /// Priced per item: onions, avocados, a head of broccoli.
        case each
        /// Priced per lb and bought to the nearest ¼ lb: meat from the counter.
        case weight
        /// Priced per package of `size` `unit`: a dozen eggs, an 8 oz bag of cheese.
        case package
    }

    let name: String
    let aisle: String
    let isStaple: Bool
    /// Goes bad within about a week once bought or opened.
    let perishable: Bool
    let soldBy: SoldBy
    /// "8 oz bag (2 cups)"
    let package: String
    let size: Double
    let unit: String
    /// US dollars per package (per lb when sold by weight).
    let price: Double

    var sizeInBase: Double { Units.toBase(Amount(value: size, unit: unit)) }

    func canMeasure(_ unit: String) -> Bool {
        (Units.family(of: unit) ?? unit) == (Units.family(of: self.unit) ?? self.unit)
    }
}

/// What to put in the cart for one shopping-list item.
struct Purchase: Hashable, Sendable {
    /// "1 dozen", "2 × 8 oz bag (2 cups)", "about 1½ lb", "3"
    let text: String
    let cost: Double
    /// What's left after cooking, e.g. "½ cup". nil when it's nothing worth mentioning.
    let leftoverText: String?
    /// Dollar value of the unused part.
    let leftoverValue: Double
}

struct IngredientCatalog: Sendable {
    private let items: [String: CatalogItem]

    init(items: [CatalogItem]) {
        self.items = Dictionary(items.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
    }

    static func bundled(_ bundle: Bundle = .main) -> IngredientCatalog {
        guard let url = bundle.url(forResource: "ingredients", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([CatalogItem].self, from: data) else {
            assertionFailure("ingredients.json is missing or malformed")
            return IngredientCatalog(items: [])
        }
        return IngredientCatalog(items: items)
    }

    var names: [String] { items.values.map(\.name).sorted() }

    func item(named name: String) -> CatalogItem? { items[name.lowercased()] }

    /// Turns the amounts a plan needs into packages to buy.
    /// Returns nil if the ingredient isn't in the catalog or a recipe measures it in a way
    /// the package can't be compared with (an AI recipe asking for "1 cup" of avocado).
    func purchase(of name: String, for needs: [Amount]) -> Purchase? {
        guard let item = item(named: name), needs.allSatisfy({ item.canMeasure($0.unit) }) else { return nil }
        let needed = needs.reduce(0) { $0 + Units.toBase($1) }

        // "To taste" only (salt): one package covers it.
        guard needed > 0 else {
            return Purchase(text: item.package, cost: item.price, leftoverText: nil, leftoverValue: 0)
        }

        switch item.soldBy {
        case .weight:
            let pounds = max(0.25, ((needed / 16) * 4 - 1e-6).rounded(.up) / 4)
            return Purchase(text: "about " + Amount(value: pounds, unit: "lb").formatted,
                            cost: pounds * item.price, leftoverText: nil, leftoverValue: 0)

        case .each, .package:
            let size = item.sizeInBase
            let count = max(1, (needed / size - 1e-6).rounded(.up))
            let leftover = count * size - needed
            let leftoverShare = leftover / size
            let text = switch item.soldBy {
            case .each: Amount(value: count, unit: item.unit).formatted
            default: count == 1 ? item.package : "\(Int(count)) × \(item.package)"
            }
            return Purchase(
                text: text,
                cost: count * item.price,
                leftoverText: leftoverShare >= 0.1 ? Units.formatBase(leftover, like: item.unit) : nil,
                leftoverValue: leftoverShare * item.price
            )
        }
    }

    /// What a recipe's ingredients cost per serving if you only paid for what you use.
    /// Pantry staples aren't counted. Returns nil if nothing could be priced.
    func costPerServing(of recipe: Recipe) -> Double? {
        var total = 0.0
        var priced = 0
        for ingredient in recipe.shoppingIngredients {
            guard let amount = ingredient.amount, let item = item(named: ingredient.name),
                  item.canMeasure(ingredient.unit) else { continue }
            let base = Units.toBase(Amount(value: amount, unit: ingredient.unit))
            total += item.soldBy == .weight ? base / 16 * item.price : base / item.sizeInBase * item.price
            priced += 1
        }
        return priced == 0 ? nil : total / Double(max(recipe.servings, 1))
    }

    func tags(for recipe: Recipe) -> [RecipeTag] {
        RecipeTag.tags(for: recipe)
    }
}

extension Double {
    /// "$3.49"
    var dollars: String { formatted(.currency(code: "USD")) }
}
