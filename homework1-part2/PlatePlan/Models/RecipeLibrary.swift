import Foundation
import Observation

/// The bundled recipes (built by Scripts/build_recipes.py) plus any AI recipes the user saved.
@MainActor
@Observable
final class RecipeLibrary {
    let bundled: [Recipe]
    let catalog: IngredientCatalog
    private(set) var saved: [Recipe] {
        didSet { persistSaved() }
    }
    @ObservationIgnored private var savedURL: URL?

    var recipes: [Recipe] { bundled + saved }

    /// Filter chips: world flavors, the fixed categories, plus "My Recipes" once something is saved.
    var categories: [String] {
        [RecipeCategory.world] + RecipeCategory.all + (saved.isEmpty ? [] : [RecipeCategory.saved])
    }

    /// Every ingredient name the app knows. The AI maps photo items and new recipes onto these.
    var ingredientNames: [String] {
        Array(Set(catalog.names + recipes.flatMap { $0.ingredients.map(\.name) })).sorted()
    }

    init(bundled: [Recipe], catalog: IngredientCatalog = IngredientCatalog(items: []), savedURL: URL? = nil) {
        // Keep the authored order within each category, but group categories in chip order.
        let rank = Dictionary(uniqueKeysWithValues: RecipeCategory.all.enumerated().map { ($1, $0) })
        self.bundled = bundled.enumerated()
            .sorted { (rank[$0.element.category] ?? 99, $0.offset) < (rank[$1.element.category] ?? 99, $1.offset) }
            .map(\.element)
        self.catalog = catalog
        self.savedURL = savedURL
        if let savedURL, let data = try? Data(contentsOf: savedURL),
           let saved = try? JSONDecoder().decode([Recipe].self, from: data) {
            self.saved = saved
        } else {
            self.saved = []
        }
    }

    convenience init() {
        let bundled: [Recipe]
        if let url = Bundle.main.url(forResource: "recipes", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Recipe].self, from: data) {
            bundled = decoded
        } else {
            assertionFailure("recipes.json is missing or malformed")
            bundled = []
        }
        let savedURL = URL.applicationSupportDirectory.appending(path: "saved-recipes.json")
        self.init(bundled: bundled, catalog: .bundled(), savedURL: savedURL)
    }

    /// Switches to the recipes an account saved. Recipes saved before accounts existed go to the
    /// first account that signs in.
    func load(account: String) {
        let support = URL.applicationSupportDirectory
        let url = support.appending(path: "accounts/\(AccountStore.storageID(account))/saved-recipes.json")
        let shared = support.appending(path: "saved-recipes.json")
        let files = FileManager.default
        if !files.fileExists(atPath: url.path), files.fileExists(atPath: shared.path) {
            try? files.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? files.moveItem(at: shared, to: url)
        }
        savedURL = url
        saved = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode([Recipe].self, from: $0) } ?? []
    }

    /// Deletes this account's saved recipes and their photos (when the account is deleted).
    func eraseSaved() {
        for recipe in saved { try? FileManager.default.removeItem(at: Self.photoFile(for: recipe.id)) }
        saved = []
        if let savedURL { try? FileManager.default.removeItem(at: savedURL) }
    }

    func recipe(id: String) -> Recipe? { recipes.first { $0.id == id } }

    func filtered(category: String?, query: String) -> [Recipe] {
        let terms = query.lowercased().split(separator: " ")
        return recipes.filter { recipe in
            let inCategory = switch category {
            case nil: true
            case RecipeCategory.saved: recipe.isCustom
            case RecipeCategory.world: recipe.cuisine != "American"
            case let category?: recipe.category == category && !recipe.isCustom
            }
            return inCategory && terms.allSatisfy { recipe.searchText.contains($0) }
        }
    }

    func isSaved(_ recipe: Recipe) -> Bool { saved.contains { $0.id == recipe.id } }

    func save(_ recipe: Recipe) {
        guard !isSaved(recipe) else { return }
        var recipe = recipe
        recipe.isCustom = true
        saved.append(recipe)
        if let url = recipe.photoURL.flatMap(URL.init(string:)) {
            let destination = Self.photoFile(for: recipe.id)
            Task.detached(priority: .utility) {
                guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
                try? FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                                         withIntermediateDirectories: true)
                try? data.write(to: destination, options: .atomic)
            }
        }
    }

    /// Where a saved AI recipe's photo is kept on the phone.
    nonisolated static func photoFile(for recipeID: String) -> URL {
        URL.applicationSupportDirectory.appending(path: "photos/\(recipeID).jpg")
    }

    func deleteSaved(_ recipe: Recipe) {
        saved.removeAll { $0.id == recipe.id }
        try? FileManager.default.removeItem(at: Self.photoFile(for: recipe.id))
    }

    private func persistSaved() {
        guard let savedURL else { return }
        do {
            try FileManager.default.createDirectory(at: savedURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try JSONEncoder().encode(saved).write(to: savedURL, options: .atomic)
        } catch {
            print("Couldn't save recipes: \(error)")
        }
    }
}
