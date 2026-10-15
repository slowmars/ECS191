import Testing
@testable import PlatePlan

struct RecipeMatcherTests {
    let omelette = TestData.recipe("Omelette", servings: 1, [
        TestData.ingredient("Eggs", 3, "", aisle: "Dairy & Eggs"),
        TestData.ingredient("Shredded cheddar", 0.25, "cup", aisle: "Dairy & Eggs"),
        TestData.ingredient("Butter", 1, "tbsp", aisle: "Dairy & Eggs"),
        TestData.ingredient("Salt", nil, "", aisle: "Pantry Staples", staple: true),
    ])
    let salad = TestData.recipe("Salad", servings: 1, [
        TestData.ingredient("Romaine lettuce", 1, "head", aisle: "Produce"),
        TestData.ingredient("Tomato", 1, "", aisle: "Produce"),
    ])

    @Test func ranksByFewestMissing() {
        let matches = RecipeMatcher.matches(for: [salad, omelette], have: ["eggs", "cheddar", "butter", "tomatoes"])
        #expect(matches.map(\.recipe.name) == ["Omelette", "Salad"])
        #expect(matches[0].canMakeNow)
        #expect(matches[1].missing == ["Romaine lettuce"])
    }

    @Test func assumesPantryStaples() {
        let match = RecipeMatcher.matches(for: [omelette], have: ["Eggs", "Shredded cheddar", "Butter"]).first
        #expect(match?.missing == [])
    }

    @Test func skipsRecipesWithNothingInCommon() {
        #expect(RecipeMatcher.matches(for: [salad], have: ["Chocolate chips"]).isEmpty)
    }

    @Test func matchesLooseNames() {
        let tokens = RecipeMatcher.tokens
        #expect(RecipeMatcher.isSameIngredient(tokens("chicken breasts"), tokens("Chicken breast")))
        #expect(RecipeMatcher.isSameIngredient(tokens("cheddar"), tokens("Shredded cheddar")))
        #expect(RecipeMatcher.isSameIngredient(tokens("Mixed berries"), tokens("berry")))
        #expect(!RecipeMatcher.isSameIngredient(tokens("Garlic powder"), tokens("Chili powder")))
    }
}
