import Foundation

struct Nutrition: Codable, Hashable, Sendable {
    /// Estimated per serving.
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
}

struct Ingredient: Codable, Hashable, Sendable {
    var name: String
    /// nil for "to taste" items like salt.
    var amount: Double?
    /// "" for plain counts ("2 eggs"); otherwise one of `Units.all`.
    var unit: String
    var note: String
    var aisle: String
    /// Salt, pepper, oil, flour... most kitchens have these already.
    var isStaple: Bool

    func amount(scaledBy factor: Double) -> Amount? {
        amount.map { Amount(value: $0 * factor, unit: unit) }
    }
}

struct Recipe: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var emoji: String
    var category: String
    var cuisine: String
    var minutes: Int
    var difficulty: String
    var servings: Int
    var nutrition: Nutrition
    var ingredients: [Ingredient]
    var steps: [String]
    /// true for recipes the AI chef wrote and the user saved.
    var isCustom: Bool = false
    /// A photo of the dish found online, for AI recipes (bundled recipes use the asset catalog).
    var photoURL: String?
    /// "Photo: TheMealDB" or the photographer and license from Wikimedia Commons.
    var photoCredit: String?
    /// Recipes the AI chef based this one on.
    var sources: [String] = []

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, category, cuisine, minutes, difficulty, servings, nutrition, ingredients, steps, isCustom
        case photoURL, photoCredit, sources
    }

    init(id: String, name: String, emoji: String, category: String, cuisine: String = "American", minutes: Int,
         difficulty: String, servings: Int, nutrition: Nutrition, ingredients: [Ingredient], steps: [String],
         isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.category = category
        self.cuisine = cuisine
        self.minutes = minutes
        self.difficulty = difficulty
        self.servings = servings
        self.nutrition = nutrition
        self.ingredients = ingredients
        self.steps = steps
        self.isCustom = isCustom
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        emoji = try c.decode(String.self, forKey: .emoji)
        category = try c.decode(String.self, forKey: .category)
        cuisine = try c.decodeIfPresent(String.self, forKey: .cuisine) ?? "American"
        minutes = try c.decode(Int.self, forKey: .minutes)
        difficulty = try c.decode(String.self, forKey: .difficulty)
        servings = try c.decode(Int.self, forKey: .servings)
        nutrition = try c.decode(Nutrition.self, forKey: .nutrition)
        ingredients = try c.decode([Ingredient].self, forKey: .ingredients)
        steps = try c.decode([String].self, forKey: .steps)
        isCustom = try c.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
        photoURL = try c.decodeIfPresent(String.self, forKey: .photoURL)
        photoCredit = try c.decodeIfPresent(String.self, forKey: .photoCredit)
        sources = try c.decodeIfPresent([String].self, forKey: .sources) ?? []
    }

    /// Ingredients you'd actually need to buy (staples excluded).
    var shoppingIngredients: [Ingredient] { ingredients.filter { !$0.isStaple } }

    /// Lowercased text used by the search bar.
    var searchText: String {
        ([name, category, cuisine] + ingredients.map(\.name)).joined(separator: " ").lowercased()
    }
}

enum RecipeCategory {
    /// Shown as filter chips, in this order.
    static let all = ["Breakfast", "Chicken", "Beef & Pork", "Seafood", "Pasta", "Vegetarian", "Desserts"]
    /// Extra chip for recipes saved from the AI chef.
    static let saved = "My Recipes"
    /// Chip for every cuisine other than American.
    static let world = "World Flavors"
}

/// Quick health labels, computed from a recipe's nutrition and ingredients.
enum RecipeTag: String, CaseIterable, Identifiable, Sendable {
    case balanced = "Balanced"
    case highProtein = "High protein"
    case veggiePacked = "Veggie-packed"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .balanced: "leaf"
        case .highProtein: "bolt"
        case .veggiePacked: "carrot"
        }
    }

    /// Flavorings that come from the produce aisle but don't count as a vegetable serving.
    private static let aromatics: Set<String> = [
        "garlic", "ginger", "lemon", "lime", "fresh basil", "fresh cilantro", "green onions",
    ]

    static func tags(for recipe: Recipe) -> [RecipeTag] {
        let n = recipe.nutrition
        let calories = Double(max(n.calories, 1))
        let proteinShare = Double(n.protein * 4) / calories
        let carbShare = Double(n.carbs * 4) / calories
        let fatShare = Double(n.fat * 9) / calories
        let vegetables = recipe.ingredients.filter {
            $0.aisle == "Produce" && !aromatics.contains($0.name.lowercased())
        }

        var tags: [RecipeTag] = []
        // Roughly the USDA ranges for a main meal: enough protein, moderate fat, sensible calories.
        if recipe.category != "Desserts", (300...700).contains(n.calories),
           proteinShare >= 0.2, fatShare <= 0.35, (0.3...0.6).contains(carbShare) {
            tags.append(.balanced)
        }
        if n.protein >= 30 { tags.append(.highProtein) }
        if vegetables.count >= 3 { tags.append(.veggiePacked) }
        return tags
    }
}

enum Aisle {
    /// Store order for the shopping list. Must match Scripts/build_recipes.py.
    static let all = [
        "Produce", "Meat & Seafood", "Dairy & Eggs", "Bakery & Tortillas", "Pasta, Rice & Grains",
        "Canned & Jarred", "Condiments & Sauces", "Spices & Baking", "Frozen", "Pantry Staples",
    ]
    static let staples = "Pantry Staples"
    static let other = "Other"
}
