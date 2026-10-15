import Testing
@testable import PlatePlan

struct ShoppingListTests {
    let catalog = TestData.catalog

    @Test func mergesScalesAndGroupsByAisle() throws {
        let tacos = TestData.recipe("Tacos", servings: 4, [
            TestData.ingredient("Ground beef", 1, "lb", aisle: "Meat & Seafood"),
            TestData.ingredient("Yellow onion", 1, "", aisle: "Produce"),
        ])
        let chili = TestData.recipe("Chili", servings: 6, [
            TestData.ingredient("Ground beef", 1, "lb", aisle: "Meat & Seafood"),
            TestData.ingredient("Salt", nil, "", aisle: "Pantry Staples", staple: true),
        ])

        // Tacos for 2 (half) + chili for 6 (as written).
        let report = ShoppingList.build(from: [(tacos, 2), (chili, 6)], catalog: catalog)

        #expect(report.sections.map(\.aisle) == ["Produce", "Meat & Seafood"])
        let beef = try #require(report.sections[1].items.first)
        #expect(beef.amountText == "1½ lb")
        #expect(beef.recipeNames == ["Tacos", "Chili"])
        #expect(beef.purchase?.text == "about 1½ lb")
        #expect(abs((beef.purchase?.cost ?? 0) - 1.5 * 5.49) < 0.001)
        // Staples are assumed to be at home and don't count toward the total.
        #expect(report.atHome.map(\.name) == ["Salt"])
        #expect(abs(report.totalCost - (1.5 * 5.49 + 0.90)) < 0.001)
    }

    @Test func buysWholePackagesAndTracksLeftovers() throws {
        let omelette = TestData.recipe("Omelette", servings: 1, [
            TestData.ingredient("Eggs", 3, "", aisle: "Dairy & Eggs"),
            TestData.ingredient("Heavy cream", 0.5, "cup", aisle: "Dairy & Eggs"),
        ])
        let report = ShoppingList.build(from: [(omelette, 1)], catalog: catalog)
        let eggs = try #require(report.toBuy.first { $0.name == "Eggs" })
        #expect(eggs.purchase?.text == "1 dozen")
        #expect(eggs.purchase?.leftoverText == "9")
        // Eggs keep for weeks; the opened cream doesn't, so only the cream counts as waste.
        #expect(report.leftovers.map(\.name) == ["Heavy cream"])
        #expect(abs(report.wasteValue - 0.75 * 4.29) < 0.001)
        #expect(abs(report.pantryValue - 9.0 / 12 * 3.49) < 0.001)
    }

    @Test func respectsWhatsAtHome() {
        let recipe = TestData.recipe("Eggs", servings: 1, [TestData.ingredient("Eggs", 2, "", aisle: "Dairy & Eggs")])
        let report = ShoppingList.build(from: [(recipe, 1)], catalog: catalog) { name, _ in name == "eggs" }
        #expect(report.toBuy.isEmpty)
        #expect(report.totalCost == 0)
    }

    @Test func checkKeyChangesWhenAmountChanges() {
        let recipe = TestData.recipe("Eggs", servings: 1, [TestData.ingredient("Eggs", 2, "", aisle: "Dairy & Eggs")])
        let one = ShoppingList.build(from: [(recipe, 1)], catalog: catalog).toBuy[0]
        let two = ShoppingList.build(from: [(recipe, 2)], catalog: catalog).toBuy[0]
        #expect(one.checkKey != two.checkKey)
    }
}

struct SavingsAdvisorTests {
    @Test func suggestsMealsThatUseLeftovers() throws {
        let catalog = TestData.catalog
        let alfredo = TestData.recipe("Alfredo", servings: 4, [TestData.ingredient("Heavy cream", 0.5, "cup", aisle: "Dairy & Eggs")])
        let soup = TestData.recipe("Tomato Soup", servings: 4, [TestData.ingredient("Heavy cream", 0.5, "cup", aisle: "Dairy & Eggs")])
        let omelette = TestData.recipe("Omelette", servings: 1, [TestData.ingredient("Eggs", 3, "", aisle: "Dairy & Eggs")])

        let suggestions = SavingsAdvisor.suggestions(for: [(alfredo, 4)], candidates: [alfredo, soup, omelette],
                                                     catalog: catalog, isAtHome: { _, staple in staple })
        let first = try #require(suggestions.first)
        #expect(suggestions.count == 1)
        #expect(first.recipe.name == "Tomato Soup")
        #expect(first.uses == ["Heavy cream"])
        // 1½ cups of cream are left over. Serving sizes go up to double the recipe, so the best
        // option is soup for 8, which uses 1 cup of it for free.
        #expect(first.servings == 8)
        #expect(first.addedCost == 0)
        #expect(first.extraItems.isEmpty)
        #expect(abs(first.wasteSaved - 0.5 * 4.29) < 0.001)
    }
}

struct CatalogTests {
    let catalog = TestData.catalog

    @Test func roundsMeatUpToQuarterPounds() {
        let purchase = catalog.purchase(of: "Ground beef", for: [Amount(value: 1.1, unit: "lb")])
        #expect(purchase?.text == "about 1¼ lb")
    }

    @Test func convertsRecipeUnitsToPackages() {
        // 3 tbsp + 1 cup of cream = 1 cup + 3 tbsp, which fits in one 2-cup pint.
        let purchase = catalog.purchase(of: "Heavy cream", for: [Amount(value: 3, unit: "tbsp"), Amount(value: 1, unit: "cup")])
        #expect(purchase?.text == "1 pint (2 cups)")
        #expect(purchase?.leftoverText == "¾ cup + 1 tbsp")
    }

    @Test func refusesUnitsItCantCompare() {
        #expect(catalog.purchase(of: "Eggs", for: [Amount(value: 1, unit: "cup")]) == nil)
        #expect(catalog.purchase(of: "Dragon fruit", for: [Amount(value: 1, unit: "")]) == nil)
    }

    @Test func pricesRecipesPerServing() throws {
        let recipe = TestData.recipe("Beef", servings: 4, [
            TestData.ingredient("Ground beef", 1, "lb", aisle: "Meat & Seafood"),
            TestData.ingredient("Salt", 1, "tsp", aisle: "Pantry Staples", staple: true),
        ])
        let cost = try #require(catalog.costPerServing(of: recipe))
        #expect(abs(cost - 5.49 / 4) < 0.001)
    }

    @Test func tagsHealthyCheapMeals() {
        var recipe = TestData.recipe("Bowl", servings: 4, [
            TestData.ingredient("Ground beef", 1, "lb", aisle: "Meat & Seafood"),
            TestData.ingredient("Tomato", 2, "", aisle: "Produce"),
            TestData.ingredient("Yellow onion", 1, "", aisle: "Produce"),
            TestData.ingredient("Eggs", 2, "", aisle: "Dairy & Eggs"),
            TestData.ingredient("Garlic", 2, "clove", aisle: "Produce"),
        ])
        recipe.nutrition = Nutrition(calories: 500, protein: 35, carbs: 55, fat: 15)
        #expect(catalog.tags(for: recipe) == [.balanced, .highProtein])

        recipe.nutrition = Nutrition(calories: 800, protein: 20, carbs: 40, fat: 60)
        #expect(!catalog.tags(for: recipe).contains(.balanced))
    }
}

enum TestData {
    static let catalog = IngredientCatalog(items: [
        item("Ground beef", "Meat & Seafood", .weight, "per lb", 1, "lb", 5.49, perishable: true),
        item("Yellow onion", "Produce", .each, "1 onion", 1, "", 0.90),
        item("Tomato", "Produce", .each, "1 tomato", 1, "", 0.80, perishable: true),
        item("Garlic", "Produce", .package, "1 head (about 10 cloves)", 10, "clove", 0.60),
        item("Eggs", "Dairy & Eggs", .package, "1 dozen", 12, "", 3.49),
        item("Heavy cream", "Dairy & Eggs", .package, "1 pint (2 cups)", 2, "cup", 4.29, perishable: true),
        item("Salt", "Pantry Staples", .package, "26 oz canister", 2.5, "cup", 1.29, staple: true),
    ])

    static func item(_ name: String, _ aisle: String, _ soldBy: CatalogItem.SoldBy, _ package: String,
                     _ size: Double, _ unit: String, _ price: Double,
                     perishable: Bool = false, staple: Bool = false) -> CatalogItem {
        CatalogItem(name: name, aisle: aisle, isStaple: staple, perishable: perishable, soldBy: soldBy,
                    package: package, size: size, unit: unit, price: price)
    }

    static func ingredient(_ name: String, _ amount: Double?, _ unit: String, aisle: String, staple: Bool = false) -> Ingredient {
        Ingredient(name: name, amount: amount, unit: unit, note: amount == nil ? "to taste" : "", aisle: aisle, isStaple: staple)
    }

    static func recipe(_ name: String, servings: Int, _ ingredients: [Ingredient]) -> Recipe {
        Recipe(id: name, name: name, emoji: "🍽️", category: "Chicken", minutes: 20, difficulty: "Easy",
               servings: servings, nutrition: Nutrition(calories: 400, protein: 20, carbs: 30, fat: 10),
               ingredients: ingredients, steps: ["Cook it."])
    }
}
