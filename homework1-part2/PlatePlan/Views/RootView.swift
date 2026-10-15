import SwiftUI

/// Tabs follow the user's flow, left to right: choose recipes → plan → shop.
/// Chef AI sits on the far right, the easiest spot to reach with a thumb.
struct RootView: View {
    @Environment(RecipeLibrary.self) private var library
    @Environment(MealPlan.self) private var plan
    @Environment(Router.self) private var router
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    #if DEBUG
    @State private var debugCookingRecipe: Recipe?
    #endif

    var body: some View {
        @Bindable var router = router
        let report = plan.shoppingReport(in: library)
        let itemsLeft = report.toBuy.count { !plan.isChecked($0) }
        let mealsLeft = plan.entries.count - plan.cookedCount

        TabView(selection: $router.tab) {
            Tab("Recipes", systemImage: "book", value: Router.Tab.recipes) {
                RecipesView()
            }
            Tab("My Plan", systemImage: "fork.knife", value: Router.Tab.plan) {
                PlanView()
            }
            .badge(mealsLeft)
            Tab("Shopping", systemImage: "cart", value: Router.Tab.shopping) {
                ShoppingListView(report: report)
            }
            .badge(itemsLeft)
            Tab("Chef AI", systemImage: "sparkles", value: Router.Tab.chef) {
                ChefView()
            }
        }
        .sheet(isPresented: Binding(get: { !hasSeenWelcome && !Self.skipWelcome },
                                    set: { if !$0 { hasSeenWelcome = true } })) {
            WelcomeView()
        }
        #if DEBUG
        // `-cook <recipe id>` opens cooking mode at launch (used for simulator screenshots).
        .fullScreenCover(item: $debugCookingRecipe) { CookingView(recipe: $0, servings: $0.servings) }
        .onAppear {
            debugCookingRecipe = UserDefaults.standard.string(forKey: "cook").flatMap(library.recipe(id:))
            if let open = UserDefaults.standard.string(forKey: "open").flatMap(library.recipe(id:)) {
                router.debugRecipe = open
            }
        }
        #endif
    }

    /// Debug builds accept `-tab N` at launch (used for simulator screenshots).
    static var initialTab: Router.Tab {
        #if DEBUG
        Router.Tab(rawValue: UserDefaults.standard.integer(forKey: "tab")) ?? .recipes
        #else
        .recipes
        #endif
    }

    private static var skipWelcome: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "skipWelcome")
        #else
        false
        #endif
    }
}
