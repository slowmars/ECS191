import Testing
@testable import PlatePlan

/// Guards the bundled recipe set against drifting away from the app's simplicity rules.
@MainActor
struct RecipeDataTests {
    let library = RecipeLibrary()
    var recipes: [Recipe] { library.bundled }

    @Test func loadsAllRecipes() {
        #expect(recipes.count == 74)
        #expect(Set(recipes.map(\.id)).count == recipes.count)
    }

    @Test func everyCategoryHasRecipes() {
        for category in RecipeCategory.all {
            #expect(recipes.contains { $0.category == category }, "\(category) is empty")
        }
    }

    @Test func recipesStaySimple() {
        for recipe in recipes {
            #expect(recipe.shoppingIngredients.count <= 10, "\(recipe.name) needs too many ingredients")
            #expect(recipe.steps.count <= 8, "\(recipe.name) has too many steps")
            #expect(recipe.nutrition.calories > 0)
        }
    }

    @Test func ingredientsUseKnownAislesAndUnits() {
        for ingredient in recipes.flatMap(\.ingredients) {
            #expect(Aisle.all.contains(ingredient.aisle), "\(ingredient.name) has aisle \(ingredient.aisle)")
            #expect(Units.all.contains(ingredient.unit), "\(ingredient.name) has unit \(ingredient.unit)")
        }
    }

    @Test(arguments: ["Fluffy Pancakes", "Ground Beef Tacos", "Spaghetti with Meat Sauce", "Broccoli Mac & Cheese",
                      "Chicken Stir-Fry", "Chocolate Chip Cookies", "Chicken Tikka Masala", "Grilled Lemon Herb Fish",
                      "Shrimp Pad Thai", "Greek Chicken Souvlaki with Tzatziki"])
    func includesFamousDishes(name: String) {
        #expect(recipes.contains { $0.name == name })
    }

    @Test func nutritionMatchesMacros() {
        for recipe in recipes {
            let n = recipe.nutrition
            let fromMacros = Double(4 * n.protein + 4 * n.carbs + 9 * n.fat)
            #expect(abs(fromMacros - Double(n.calories)) <= 0.12 * Double(n.calories), "\(recipe.name)")
        }
    }

    /// Package sizes (and the prices used to rank leftovers) must cover every ingredient.
    @Test func everyIngredientCanBePriced() {
        for recipe in recipes {
            for ingredient in recipe.ingredients {
                let amounts = ingredient.amount.map { [Amount(value: $0, unit: ingredient.unit)] } ?? []
                #expect(library.catalog.purchase(of: ingredient.name, for: amounts) != nil,
                        "\(recipe.name): \(ingredient.name)")
            }
            #expect(library.catalog.costPerServing(of: recipe) != nil, "\(recipe.name)")
        }
    }

    @Test func plentyOfHealthyAndWorldOptions() {
        let balanced = recipes.filter { library.catalog.tags(for: $0).contains(.balanced) }
        let world = library.filtered(category: RecipeCategory.world, query: "")
        #expect(balanced.count >= 14)
        #expect(world.count >= 20)
        #expect(library.filtered(category: nil, query: "indian").count == 6)
    }
}
