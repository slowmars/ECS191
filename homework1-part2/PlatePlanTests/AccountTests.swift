import Foundation
import Testing
@testable import PlatePlan

@MainActor
struct AccountTests {
    private func ingredient(_ name: String, aisle: String = "Produce") -> Ingredient {
        Ingredient(name: name, amount: 1, unit: "", note: "", aisle: aisle, isStaple: false)
    }

    private func recipe(_ ingredients: [Ingredient]) -> Recipe {
        Recipe(id: "test", name: "Test", emoji: "🍲", category: "Vegetarian", minutes: 10, difficulty: "Easy",
               servings: 2, nutrition: Nutrition(calories: 400, protein: 20, carbs: 40, fat: 10),
               ingredients: ingredients, steps: ["Cook."])
    }

    /// A fresh store that doesn't touch the app's real saved accounts.
    private func makeStore() -> AccountStore {
        let defaults = UserDefaults(suiteName: "AccountTests-\(UUID().uuidString)")!
        return AccountStore(defaults: defaults)
    }

    @Test func dietsExcludeTheRightFoods() {
        let shrimp = recipe([ingredient("Shrimp", aisle: "Meat & Seafood")])
        let chickenBroth = recipe([ingredient("Chicken broth", aisle: "Canned & Jarred")])
        let eggs = recipe([ingredient("Eggs", aisle: "Dairy & Eggs")])
        let cheese = recipe([ingredient("Shredded cheddar", aisle: "Dairy & Eggs")])
        let honey = recipe([ingredient("Honey", aisle: "Condiments & Sauces")])
        let plants = recipe([ingredient("Eggplant"), ingredient("Light coconut milk", aisle: "Canned & Jarred"),
                             ingredient("Vegetable broth", aisle: "Canned & Jarred")])

        #expect(Diet.pescatarian.allows(shrimp))
        #expect(!Diet.pescatarian.allows(chickenBroth))
        #expect(!Diet.eggetarian.allows(shrimp))
        #expect(Diet.eggetarian.allows(eggs))
        #expect(!Diet.vegetarian.allows(eggs))
        #expect(Diet.vegetarian.allows(cheese))
        #expect(!Diet.vegan.allows(cheese))
        #expect(!Diet.vegan.allows(honey))
        #expect(Diet.vegan.allows(plants))
    }

    @Test func dietFilterStartsOffAndShowsEverything() {
        let store = makeStore()
        let library = RecipeLibrary()
        store.signIn(id: "email:new@example.com", method: .email, name: "New", contact: "")
        #expect(store.current?.dietFilter == nil)
        #expect(library.bundled.allSatisfy(store.shows))

        store.update { $0.dietFilter = .nonVegetarian }
        let nonVeg = library.bundled.filter(store.shows)
        #expect(!nonVeg.isEmpty && nonVeg.count < library.bundled.count)
        #expect(!nonVeg.contains { Diet.vegetarian.allows($0) }, "Non-veg shows only dishes with meat or fish")

        store.update { $0.dietFilter = nil }
        #expect(library.bundled.allSatisfy(store.shows))
    }

    @Test func allergensAreDetected() {
        func has(_ name: String, _ allergy: Allergy, aisle: String = "Pantry Staples") -> Bool {
            allergy.isIn(ingredient(name, aisle: aisle))
        }
        #expect(has("Peanut butter", .peanuts))
        #expect(has("Basil pesto", .treeNuts))
        #expect(has("Basil pesto", .dairy))
        #expect(has("Flour tortillas", .gluten))
        #expect(!has("Corn tortillas", .gluten))
        #expect(has("Spaghetti", .gluten))
        #expect(!has("Rice noodles", .gluten))
        #expect(has("Soy sauce", .gluten) && has("Soy sauce", .soy))
        #expect(has("Extra-firm tofu", .soy))
        #expect(has("Hummus", .sesame))
        #expect(has("Fish sauce", .fish) && !has("Fish sauce", .shellfish))
        #expect(has("Shrimp", .shellfish, aisle: "Meat & Seafood") && !has("Shrimp", .fish, aisle: "Meat & Seafood"))
        #expect(has("Eggs", .eggs, aisle: "Dairy & Eggs") && !has("Eggplant", .eggs, aisle: "Produce"))
        #expect(!has("Light coconut milk", .dairy))
        #expect(!has("Hamburger buns", .peanuts) && has("Hamburger buns", .gluten))
    }

    @Test func allergiesHideRecipes() {
        let store = makeStore()
        let library = RecipeLibrary()
        store.signIn(id: "email:allergic@example.com", method: .email, name: "A", contact: "")
        store.update { $0.allergies = [.peanuts] }
        let peanutNoodles = library.bundled.first { $0.id == "peanut-noodles" }
        #expect(peanutNoodles != nil && !store.shows(peanutNoodles!))
        #expect(library.bundled.filter(store.shows).count > 60, "Most recipes don't contain peanuts")

        store.update { $0.allergies = Set(Allergy.allCases) }
        #expect(library.bundled.filter(store.shows).count < 15)
    }

    @Test func everyDietHasBundledRecipes() {
        let library = RecipeLibrary()
        for diet in Diet.allCases {
            #expect(library.bundled.contains(where: diet.allows), "No recipes for \(diet.rawValue)")
        }
    }

    @Test func emailAccountsNeedTheRightPassword() throws {
        let store = makeStore()
        try store.createAccount(name: "Sam Lee", email: "Sam@Example.com", password: "password1")
        #expect(store.current?.firstName == "Sam")
        store.signOut()
        #expect(store.current == nil)

        #expect(throws: AccountStore.AuthError.wrongPassword) {
            try store.signIn(email: "sam@example.com", password: "nope-nope")
        }
        try store.signIn(email: " sam@example.com ", password: "password1")
        #expect(store.current?.name == "Sam Lee")
        #expect(throws: AccountStore.AuthError.accountExists) {
            try store.createAccount(name: "Sam", email: "sam@example.com", password: "password2")
        }
    }

    @Test func preferencesSurviveSigningOut() {
        let store = makeStore()
        store.signIn(id: "phone:+15305551234", method: .phone, name: "Priya", contact: "+15305551234")
        store.update { $0.dietFilter = .vegan; $0.allergies = [.peanuts] }
        store.signOut()
        store.signIn(id: "phone:+15305551234", method: .phone, name: "", contact: "")
        #expect(store.current?.dietFilter == .vegan)
        #expect(store.current?.chefNote.contains("peanuts") == true)
    }

    @Test func deletingRemovesTheAccount() {
        let store = makeStore()
        store.signIn(id: "apple:123", method: .apple, name: "Jo", contact: "")
        store.deleteAccount()
        #expect(store.current == nil)
        #expect(store.existing("apple:123") == nil)
    }

    @Test func eachAccountHasItsOwnPlan() {
        let defaults = UserDefaults(suiteName: "AccountTests-\(UUID().uuidString)")!
        let library = RecipeLibrary()
        let plan = MealPlan(defaults: defaults)
        plan.add(library.bundled[0])  // made before accounts existed

        plan.load(account: "email:first@example.com")
        #expect(plan.contains(library.bundled[0]), "The first account keeps the existing plan")
        plan.add(library.bundled[1])

        plan.load(account: "email:second@example.com")
        #expect(plan.entries.isEmpty, "A new account starts with an empty plan")
        plan.add(library.bundled[2])

        plan.load(account: "email:first@example.com")
        #expect(plan.entries.map(\.recipeID) == [library.bundled[0].id, library.bundled[1].id])

        plan.erase()
        plan.load(account: "email:first@example.com")
        #expect(plan.entries.isEmpty)
    }

    @Test func phoneNumbersAreNormalized() throws {
        #expect(try AccountStore.phoneNumber("(530) 555-1234") == "+15305551234")
        #expect(try AccountStore.phoneNumber("1 530 555 1234") == "+15305551234")
        #expect(throws: AccountStore.AuthError.invalidPhone) { try AccountStore.phoneNumber("555-1234") }
    }

    @Test func greetingFollowsTheClock() {
        func at(_ hour: Int) -> Date { Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now)! }
        #expect(RecipesView.greeting(at: at(8), name: "Alex") == "Good morning, Alex")
        #expect(RecipesView.greeting(at: at(13), name: "Alex") == "Good afternoon, Alex")
        #expect(RecipesView.greeting(at: at(19), name: "") == "Good evening")
        #expect(RecipesView.greeting(at: at(23), name: "Alex") == "Good evening, Alex")
        #expect(RecipesView.greeting(at: at(2), name: "Alex") == "Good evening, Alex")
    }

    @Test func newRecipesStartSmallUnlessAsked() {
        #expect(!RecipeGenerator.asksForServings(.dish("Chocolate cake")))
        #expect(!RecipeGenerator.asksForServings(.dish("Chicken 65")))
        #expect(RecipeGenerator.asksForServings(.dish("Lasagna for 6")))
        #expect(RecipeGenerator.asksForServings(.dish("chili for four people")))
        #expect(RecipeGenerator.asksForServings(.dish("tacos, serves 8")))
    }

    @Test func speechSpellsOutShorthand() {
        #expect(StepReader.speakable("Add 1½ tbsp oil") == "Add 1 and a half tablespoons oil")
        #expect(StepReader.speakable("Add ½ cup milk") == "Add a half cup milk")
        #expect(StepReader.speakable("Bake at 400°F for 20 min.") == "Bake at 400 degrees for 20 minutes")
    }
}
