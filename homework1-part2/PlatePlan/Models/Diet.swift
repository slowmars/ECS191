import Foundation
import Synchronization

/// The diet filter on the Recipes tab. With no filter, everything shows. "Non-veg" shows dishes with
/// meat or fish; the others show what someone on that diet can eat. The chosen filter also shapes
/// Tonight's picks and what Chef AI suggests.
enum Diet: String, Codable, CaseIterable, Identifiable, Sendable {
    case nonVegetarian = "Non-vegetarian"
    case pescatarian = "Pescatarian"
    case eggetarian = "Eggetarian"
    case vegetarian = "Vegetarian"
    case vegan = "Vegan"

    var id: String { rawValue }

    /// For the filter chips on the Recipes tab.
    var shortName: String {
        self == .nonVegetarian ? "Non-veg" : rawValue
    }

    var detail: String {
        switch self {
        case .nonVegetarian: "Dishes with meat, poultry or fish"
        case .pescatarian: "Vegetarian, plus fish and seafood"
        case .eggetarian: "Vegetarian, plus eggs"
        case .vegetarian: "No meat, poultry, fish or eggs"
        case .vegan: "No animal products, including dairy and honey"
        }
    }

    var emoji: String {
        switch self {
        case .nonVegetarian: "🍗"
        case .pescatarian: "🐟"
        case .eggetarian: "🥚"
        case .vegetarian: "🧀"
        case .vegan: "🌱"
        }
    }

    /// What this diet leaves out.
    private var excludes: Set<FoodGroup> {
        switch self {
        case .nonVegetarian: []
        case .pescatarian: [.meat]
        case .eggetarian: [.meat, .seafood]
        case .vegetarian: [.meat, .seafood, .eggs]
        case .vegan: [.meat, .seafood, .eggs, .dairy, .honey]
        }
    }

    func allows(_ recipe: Recipe) -> Bool {
        if self == .nonVegetarian {
            return recipe.ingredients.contains { !FoodGroup.groups(of: $0).isDisjoint(with: [.meat, .seafood]) }
        }
        return recipe.ingredients.allSatisfy { excludes.isDisjoint(with: FoodGroup.groups(of: $0)) }
    }
}

/// Common allergens. Recipes containing them are hidden, and Chef AI leaves them out.
/// Detection works from ingredient names, so it can't know about traces or brand recipes:
/// the app always tells people to read labels.
enum Allergy: String, Codable, CaseIterable, Identifiable, Sendable {
    case peanuts = "Peanuts"
    case treeNuts = "Tree nuts"
    case dairy = "Dairy"
    case eggs = "Eggs"
    case gluten = "Gluten"
    case soy = "Soy"
    case fish = "Fish"
    case shellfish = "Shellfish"
    case sesame = "Sesame"

    var id: String { rawValue }

    /// Words that mean an ingredient contains this allergen. Words of 4 letters or fewer must match
    /// a whole word ("bun" but not "bunch"); longer ones can appear anywhere ("breadcrumbs").
    private var keywords: [String] {
        switch self {
        case .peanuts: ["peanut"]
        case .treeNuts: ["almond", "cashew", "walnut", "pecan", "pistachio", "hazelnut", "macadamia", "pine nut",
                         "pesto", "praline", "marzipan", "nutella"]
        case .dairy, .eggs: []  // worked out by FoodGroup, which also knows plant milks and eggplant
        case .gluten: ["flour", "bread", "crouton", "noodle", "macaroni", "spaghetti", "penne", "fettuccine",
                       "ziti", "lasagna", "pasta", "tortilla", "bun", "buns", "naan", "pita", "granola", "oats",
                       "soy sauce", "teriyaki", "hoisin", "couscous", "barley", "rye", "bulgur", "seitan",
                       "panko", "cracker", "wheat", "biscuit", "dumpling", "croissant", "beer", "orzo"]
        case .soy: ["soy", "soybean", "tofu", "teriyaki", "edamame", "miso", "tempeh", "hoisin"]
        case .fish: ["fish", "salmon", "tuna", "cod", "tilapia", "anchov", "worcestershire", "caesar", "halibut",
                     "trout", "sardine", "mackerel", "bass"]
        case .shellfish: ["shrimp", "prawn", "crab", "lobster", "scallop", "clam", "clams", "mussel", "oyster",
                          "crawfish", "squid", "calamari", "octopus"]
        case .sesame: ["sesame", "tahini", "hummus", "furikake"]
        }
    }

    /// Gluten-free foods whose names contain a gluten word.
    private static let glutenFree = ["rice noodle", "corn tortilla", "almond flour", "rice flour", "coconut flour",
                                     "corn flour", "chickpea flour", "gluten-free", "gluten free", "buckwheat"]

    func isIn(_ ingredient: Ingredient) -> Bool {
        switch self {
        case .dairy: return FoodGroup.groups(of: ingredient).contains(.dairy)
        case .eggs: return FoodGroup.groups(of: ingredient).contains(.eggs)
        default: break
        }
        var name = ingredient.name.lowercased()
        if self == .gluten { for safe in Self.glutenFree { name = name.replacingOccurrences(of: safe, with: "") } }
        let words = Set(name.split { !$0.isLetter }.map(String.init))
        return keywords.contains { $0.count <= 4 ? words.contains($0) : name.contains($0) }
    }

    /// Whether a recipe is safe for someone avoiding all of `allergies`.
    static func isSafe(_ recipe: Recipe, avoiding allergies: Set<Allergy>) -> Bool {
        allergies.isEmpty || recipe.ingredients.allSatisfy { ingredient in
            !allergies.contains { allergen(ingredient: ingredient, $0) }
        }
    }

    /// Cached by allergen, aisle and name, since browsing checks every recipe many times per screen.
    private static let cache = Mutex<[String: Bool]>([:])

    private static func allergen(ingredient: Ingredient, _ allergy: Allergy) -> Bool {
        let key = allergy.rawValue + "|" + ingredient.aisle + "|" + ingredient.name
        if let cached = cache.withLock({ $0[key] }) { return cached }
        let found = allergy.isIn(ingredient)
        cache.withLock { $0[key] = found }
        return found
    }
}

/// Animal-derived food groups, worked out from an ingredient's aisle and name.
enum FoodGroup: Sendable {
    case meat, seafood, eggs, dairy, honey

    private static let meatWords = ["chicken", "beef", "pork", "steak", "sausage", "bacon", "ham", "turkey",
                                    "lamb", "prosciutto", "pepperoni", "chorizo", "gelatin", "lard"]
    private static let seafoodWords = ["fish", "salmon", "shrimp", "tuna", "prawn", "crab", "anchov", "cod",
                                       "tilapia", "scallop", "clam", "mussel", "oyster", "squid", "worcestershire",
                                       "caesar"]
    private static let eggWords = ["egg", "eggs", "mayonnaise", "mayo", "caesar"]
    private static let dairyWords = ["butter", "cheese", "cheddar", "mozzarella", "parmesan", "feta", "ricotta",
                                     "cream", "milk", "yogurt", "ghee", "paneer", "naan", "pesto", "caesar"]
    /// Plant foods whose names sound like animal ones.
    private static let plantOnly = ["coconut milk", "almond milk", "oat milk", "soy milk", "peanut butter",
                                    "almond butter", "cream of tartar", "eggplant", "vegetable broth"]

    /// Results by aisle and name. Browsing checks every recipe's ingredients many times per screen,
    /// so each ingredient is worked out once.
    private static let cache = Mutex<[String: Set<FoodGroup>]>([:])

    static func groups(of ingredient: Ingredient) -> Set<FoodGroup> {
        let key = ingredient.aisle + "|" + ingredient.name
        if let cached = cache.withLock({ $0[key] }) { return cached }
        let groups = classify(ingredient)
        cache.withLock { $0[key] = groups }
        return groups
    }

    private static func classify(_ ingredient: Ingredient) -> Set<FoodGroup> {
        var name = ingredient.name.lowercased()
        for plant in plantOnly { name = name.replacingOccurrences(of: plant, with: "") }
        let words = Set(name.split { !$0.isLetter }.map(String.init))
        func mentions(_ list: [String]) -> Bool {
            list.contains { term in words.contains(term) || (term.count > 4 && name.contains(term)) }
        }

        var groups: Set<FoodGroup> = []
        if mentions(meatWords) { groups.insert(.meat) }
        if mentions(seafoodWords) { groups.insert(.seafood) }
        if mentions(eggWords) { groups.insert(.eggs) }
        if mentions(dairyWords) { groups.insert(.dairy) }
        if words.contains("honey") { groups.insert(.honey) }
        // Anything else from the meat counter is meat; anything else from the dairy case is dairy.
        if ingredient.aisle == "Meat & Seafood", groups.isDisjoint(with: [.meat, .seafood]) { groups.insert(.meat) }
        if ingredient.aisle == "Dairy & Eggs", groups.isDisjoint(with: [.eggs, .dairy]) { groups.insert(.dairy) }
        return groups
    }
}
