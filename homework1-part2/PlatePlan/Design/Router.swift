import Observation

/// App-wide navigation state, so any screen can send the user to the right place
/// (an empty plan points to Recipes, a failed search hands off to Chef AI).
@MainActor
@Observable
final class Router {
    enum Tab: Int, Hashable {
        case recipes, plan, shopping, chef
    }

    var tab: Tab
    /// A dish for Chef AI to write, handed over from a search with no results.
    var pendingDish: String?
    #if DEBUG
    /// `-open <recipe id>` at launch shows a recipe page (used for simulator screenshots).
    var debugRecipe: Recipe?
    #endif

    init(tab: Tab = .recipes) {
        self.tab = tab
    }

    func askChef(for dish: String) {
        pendingDish = dish
        tab = .chef
    }
}
