import Foundation

/// Writes recipes on request ("chicken tikka masala") or from ingredients the user has.
///
/// Accuracy comes first: Claude looks up two or three well-regarded versions of the dish on the web,
/// writes a faithful home version from them, and checks its own ratios, times and temperatures.
/// Recipes come back in the same shape as the bundled ones, so they work with the plan,
/// servings scaling and the shopping list.
struct RecipeGenerator: Sendable {
    enum Request: Sendable {
        /// "Chicken tikka masala", "something cozy with potatoes"...
        case dish(String)
        /// Build a recipe around what's in the fridge.
        case using(ingredients: [String])
        /// A specific dish, made with what the user has where the dish allows.
        case idea(String, have: [String])
        /// Change an existing recipe: "make it vegetarian", "for 1 person".
        case tweak(Recipe, String)
    }

    private struct Response: Decodable {
        let message: String
        let recipe: GeneratedRecipe?
    }

    private struct GeneratedRecipe: Decodable {
        let name: String
        let photoSearch: String
        let sources: [String]
        let emoji: String
        let category: String
        let cuisine: String
        let minutes: Int
        let difficulty: String
        let servings: Int
        let nutrition: Nutrition
        let ingredients: [Ingredient]
        let steps: [String]
    }

    struct Output: Sendable {
        let recipe: Recipe?
        /// A short note from the chef, or why there's no recipe.
        let message: String
        /// What to search for to find a photo of the dish.
        var photoSearch: String = ""
    }

    let client: ClaudeClient

    static let schema = Schema.object([
        "message": Schema.string,
        "recipe": Schema.nullable(Schema.object([
            "name": Schema.string,
            "emoji": Schema.string,
            "category": Schema.oneOf(RecipeCategory.all),
            "cuisine": Schema.string,
            "minutes": Schema.integer,
            "difficulty": Schema.oneOf(["Easy", "Medium"]),
            "servings": Schema.integer,
            "nutrition": Schema.object([
                "calories": Schema.integer,
                "protein": Schema.integer,
                "carbs": Schema.integer,
                "fat": Schema.integer,
            ]),
            "ingredients": Schema.array(of: Schema.object([
                "name": Schema.string,
                "amount": Schema.nullable(Schema.number),
                "unit": Schema.oneOf(Units.all),
                "note": Schema.string,
                "aisle": Schema.oneOf(Aisle.all),
                "isStaple": Schema.boolean,
            ])),
            "steps": Schema.array(of: Schema.string),
            "sources": Schema.array(of: Schema.string),
            "photoSearch": Schema.string,
        ])),
    ])

    static func systemPrompt(knownIngredients: [String]) -> String {
        """
        You are the chef inside Cookd, a meal-planning app for home cooks in the US, many of them \
        college students cooking for themselves. People ask for dishes they already know and love, so \
        accuracy matters most: someone who grew up eating this dish should recognize your recipe as right.

        How to work:
        1. Search the web for the dish once (at most three searches). Favor well-regarded recipe sources: \
        Serious Eats, NYT Cooking, BBC Good Food, King Arthur Baking, Bon Appétit, RecipeTin Eats, and \
        respected cooks who specialize in that cuisine (for example Swasthi's Recipes for Indian food, \
        Maangchi for Korean, Hot Thai Kitchen for Thai). Compare two or three versions.
        2. Write a home version that keeps every defining ingredient, spice and technique of the dish, \
        with amounts, temperatures and times consistent with those sources. Don't trade authentic flavor \
        for fewer ingredients, and don't invent shortcuts that change the dish. If you leave something \
        optional out or simplify a step, say so in "message".
        3. Before answering, check your work: salt, liquid and spice amounts make sense for the servings; \
        times and temperatures are realistic; steps are in the right order; every ingredient used in the \
        steps is in the ingredient list, and every listed ingredient is used.

        Format:
        - Up to 18 ingredients and up to 10 steps; list whole spices separately. Each step is one to three clear sentences with heat \
        levels, times and doneness cues (for example "until the chicken reaches 165°F").
        - Home equipment only: stovetop, oven, microwave, blender, baking sheet, pots and pans.
        - US units. "unit" is one of the allowed values; use "" for whole items counted by number \
        ("2" eggs). "amount" is null only for "to taste" items, and then "note" says "to taste".
        - Write for 2 servings (1 if the person cooks for one), and scale every amount correctly. Only \
        use another number if the person asks for one. Even for dishes usually made in a big batch \
        (bread, cakes, cookies), write a small batch for two, such as 2 muffins or a mini loaf, \
        and set "servings" to 2.
        - If an ingredient is exactly the same thing as one of the app's ingredients below, use that \
        exact name so the shopping list can combine it. Otherwise use its normal grocery name; never \
        swap in a different ingredient just to match the list. Prep goes in "note" ("diced"), never in the name.
        - "isStaple" is true only for: Salt, Black pepper, Olive oil, Vegetable oil, All-purpose flour, \
        Granulated sugar, Baking soda, Baking powder. Their aisle is "Pantry Staples".
        - "nutrition" is your honest per-serving estimate: calories, and grams of protein, carbs and fat.
        - "minutes" is the total time, including marinating, baking or simmering.
        - "emoji" is a single emoji for the dish. "cuisine" is its origin in a word or two ("Indian").
        - "sources" lists the web addresses of the recipes you based this on (empty if you didn't search).
        - "photoSearch" is the dish's common English name, used to find a photo ("Chicken tikka masala").

        If the request isn't about food or cooking, set "recipe" to null and explain briefly in \
        "message". Otherwise "message" is one or two short, friendly sentences.

        The app's ingredients:
        \(knownIngredients.joined(separator: ", "))
        """
    }

    /// Whether the request names how many people to cook for ("for 6", "serves 4 people").
    /// Otherwise new recipes always start at 1 or 2 servings.
    static func asksForServings(_ request: Request) -> Bool {
        let text = switch request {
        case .dish(let dish): dish
        case .idea(let dish, _): dish
        case .tweak(_, let change): change
        case .using: ""
        }
        let numbers = #"(\d+|one|two|three|four|five|six|seven|eight|nine|ten|twelve|a dozen)"#
        let pattern = #"(?i)(\bfor\s+\#(numbers)\b|\bserves?\s+\#(numbers)\b|\b\#(numbers)\s+(people|persons|servings|guests)\b)"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    static func prompt(for request: Request) -> String {
        switch request {
        case .dish(let dish):
            return "Write a simple recipe for: \(dish)"
        case .using(let ingredients):
            return """
            I have these ingredients: \(ingredients.joined(separator: ", ")).
            Suggest one well-known dish that uses as many of them as makes sense and needs as few extra \
            ingredients as possible, then write an accurate recipe for it. Pantry staples are fine to use.
            """
        case .idea(let dish, let have):
            return """
            Write an accurate recipe for: \(dish)
            I have these ingredients: \(have.joined(separator: ", ")). Use them where they fit the dish, \
            but keep the dish authentic; don't force in ingredients that don't belong.
            """
        case .tweak(let recipe, let change):
            let current = (try? String(data: JSONEncoder().encode(recipe), encoding: .utf8)) ?? recipe.name
            return """
            Here is a recipe as JSON:
            \(current)

            Rewrite it with this change: \(change)
            Keep everything else the same unless the change requires it.
            """
        }
    }

    /// `preferences` is the user's diet and allergies (`Account.chefNote`), or "".
    func generate(_ request: Request, knownIngredients: [String], preferences: String = "") async throws -> Output {
        var prompt = Self.prompt(for: request)
        if !preferences.isEmpty { prompt += "\n\nAbout me: \(preferences)" }
        let response = try await client.send(
            system: Self.systemPrompt(knownIngredients: knownIngredients),
            content: [.text(prompt)],
            schema: Self.schema,
            tools: [ClaudeClient.webSearch(maxUses: 3)],
            as: Response.self
        )
        let recipe = response.recipe.map { generated in
            Recipe(
                id: "ai-" + UUID().uuidString,
                name: generated.name,
                emoji: generated.emoji,
                category: generated.category,
                cuisine: generated.cuisine,
                minutes: generated.minutes,
                difficulty: generated.difficulty,
                servings: max(1, generated.servings),
                nutrition: generated.nutrition,
                ingredients: generated.ingredients,
                steps: generated.steps,
                isCustom: true
            )
        }
        .map { recipe in
            var recipe = recipe
            recipe.sources = response.recipe?.sources ?? []
            return recipe
        }
        return Output(recipe: recipe, message: response.message, photoSearch: response.recipe?.photoSearch ?? "")
    }
}
