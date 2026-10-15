import Foundation
import Observation

/// The recipes the user picked (with how many servings of each) and which shopping-list
/// items they've ticked off. Saved to UserDefaults so the plan survives relaunches.
@MainActor
@Observable
final class MealPlan {
    struct Entry: Codable, Hashable, Sendable {
        var recipeID: String
        var servings: Int
        /// Marked done after cooking. Cooked meals stay in the plan until it's cleared.
        var cooked: Bool = false

        init(recipeID: String, servings: Int, cooked: Bool = false) {
            self.recipeID = recipeID
            self.servings = servings
            self.cooked = cooked
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            recipeID = try c.decode(String.self, forKey: .recipeID)
            servings = try c.decode(Int.self, forKey: .servings)
            cooked = try c.decodeIfPresent(Bool.self, forKey: .cooked) ?? false
        }
    }

    private(set) var entries: [Entry] {
        didSet { save() }
    }

    private(set) var checkedItems: Set<String> {
        didSet { save() }
    }

    /// Ingredients the user told us they have (true) or need to buy (false), by lowercased name.
    /// Anything not listed falls back to "staples are at home, everything else isn't".
    private(set) var pantry: [String: Bool] {
        didSet { save() }
    }

    @ObservationIgnored private let defaults: UserDefaults
    /// Each account's plan is stored under its own key (see `load(account:)`).
    @ObservationIgnored private var key = MealPlan.sharedKey
    /// Where the plan lived before accounts existed.
    private static let sharedKey = "plan.v2"

    private struct Stored: Codable {
        var entries: [Entry]
        var checkedItems: Set<String>
        var pantry: [String: Bool]?
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.data(forKey: Self.sharedKey).flatMap { try? JSONDecoder().decode(Stored.self, from: $0) }
        entries = stored?.entries ?? []
        checkedItems = stored?.checkedItems ?? []
        pantry = stored?.pantry ?? [:]
    }

    /// Switches to an account's own plan, shopping checks and pantry.
    /// A plan made before accounts existed is handed to the first account that signs in.
    func load(account: String) {
        key = Self.sharedKey + "." + AccountStore.storageID(account)
        var data = defaults.data(forKey: key)
        if data == nil, let shared = defaults.data(forKey: Self.sharedKey) {
            data = shared
            defaults.removeObject(forKey: Self.sharedKey)
        }
        let stored = data.flatMap { try? JSONDecoder().decode(Stored.self, from: $0) }
        entries = stored?.entries ?? []
        checkedItems = stored?.checkedItems ?? []
        pantry = stored?.pantry ?? [:]
    }

    /// Deletes this account's plan (when the account is deleted).
    func erase() {
        entries = []
        checkedItems = []
        pantry = [:]
        defaults.removeObject(forKey: key)
    }

    private func save() {
        let stored = Stored(entries: entries, checkedItems: checkedItems, pantry: pantry)
        defaults.set(try? JSONEncoder().encode(stored), forKey: key)
    }

    // MARK: Recipes

    func contains(_ recipe: Recipe) -> Bool { entries.contains { $0.recipeID == recipe.id } }

    func servings(for recipe: Recipe) -> Int? { entries.first { $0.recipeID == recipe.id }?.servings }

    func add(_ recipe: Recipe, servings: Int? = nil) {
        guard !contains(recipe) else { return }
        entries.append(Entry(recipeID: recipe.id, servings: servings ?? recipe.servings))
    }

    func remove(_ recipe: Recipe) {
        entries.removeAll { $0.recipeID == recipe.id }
    }

    func toggle(_ recipe: Recipe) {
        contains(recipe) ? remove(recipe) : add(recipe)
    }

    func setServings(_ servings: Int, for recipe: Recipe) {
        guard let index = entries.firstIndex(where: { $0.recipeID == recipe.id }) else { return }
        entries[index].servings = max(1, servings)
    }

    func clear() {
        entries = []
        checkedItems = []
    }

    func isCooked(_ recipe: Recipe) -> Bool { entries.first { $0.recipeID == recipe.id }?.cooked ?? false }

    func setCooked(_ cooked: Bool, for recipe: Recipe) {
        guard let index = entries.firstIndex(where: { $0.recipeID == recipe.id }) else { return }
        entries[index].cooked = cooked
    }

    var cookedCount: Int { entries.count(where: \.cooked) }

    /// Planned recipes with their servings, skipping any that no longer exist.
    func planned(in library: RecipeLibrary) -> [(recipe: Recipe, servings: Int)] {
        entries.compactMap { entry in
            library.recipe(id: entry.recipeID).map { ($0, entry.servings) }
        }
    }

    // MARK: Shopping list check-off

    func isChecked(_ item: ShoppingItem) -> Bool { checkedItems.contains(item.checkKey) }

    func toggleChecked(_ item: ShoppingItem) {
        if checkedItems.contains(item.checkKey) {
            checkedItems.remove(item.checkKey)
        } else {
            checkedItems.insert(item.checkKey)
        }
    }

    func uncheckAll() { checkedItems = [] }

    // MARK: Pantry

    func isAtHome(_ name: String, isStaple: Bool) -> Bool {
        pantry[name.lowercased()] ?? isStaple
    }

    func setAtHome(_ atHome: Bool, for item: ShoppingItem) {
        // Only remember choices that differ from the default, so the pantry stays small.
        pantry[item.id] = atHome == item.isStaple ? nil : atHome
    }

    // MARK: Shopping

    func shoppingReport(in library: RecipeLibrary) -> ShoppingReport {
        ShoppingList.build(from: planned(in: library), catalog: library.catalog, isAtHome: isAtHome)
    }
}
