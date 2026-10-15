import Foundation

/// Suggests several dishes someone could make from the ingredients they have.
///
/// This is deliberately a quick, light request (no web search): it returns ideas, not full recipes.
/// When the user picks one, `RecipeGenerator` writes the full, source-checked recipe.
struct RecipeIdeas: Sendable {
    struct Idea: Codable, Hashable, Identifiable, Sendable {
        let name: String
        let emoji: String
        let cuisine: String
        /// One sentence that makes the dish sound good and says what it is.
        let description: String
        let minutes: Int
        /// Which of the user's ingredients it uses.
        let uses: [String]
        /// What they'd still need to buy (pantry staples excluded).
        let extras: [String]
        let photoSearch: String
        var id: String { name }
    }

    struct Result: Codable, Sendable {
        let message: String
        let ideas: [Idea]
    }

    let client: ClaudeClient

    static let schema = Schema.object([
        "message": Schema.string,
        "ideas": Schema.array(of: Schema.object([
            "name": Schema.string,
            "emoji": Schema.string,
            "cuisine": Schema.string,
            "description": Schema.string,
            "minutes": Schema.integer,
            "uses": Schema.array(of: Schema.string),
            "extras": Schema.array(of: Schema.string),
            "photoSearch": Schema.string,
        ])),
    ])

    static let systemPrompt = """
        You are the chef inside Cookd, a meal-planning app for home cooks in the US, many of them \
        college students. Someone tells you what ingredients they have, and you suggest dishes they could \
        make tonight.

        Suggest every real, well-known dish that genuinely works with what they have, up to 8. A full \
        fridge usually supports 6 to 8; a handful of ingredients may only support 2 to 4. Never pad \
        the list with weak fits or made-up "medleys" and "bowls of whatever's left". Rules:
        - First suggest dishes they can make with only what they have (plus pantry staples), with \
        "extras" empty. Only after those, add dishes that need one or two extra items. Each dish uses \
        as many of their ingredients as makes sense. Assume they have pantry staples: salt, pepper, oil, flour, sugar, baking soda and \
        baking powder; never list those as extras.
        - Make the dishes genuinely different from each other: vary the cuisine and the kind of meal \
        (for example a curry, a pasta, a stir-fry, a soup, a breakfast dish), not variations of one idea.
        - Put the best fit first: the dish that uses the most of what they have with the fewest extras.
        - "uses" names only ingredients from their list. "extras" lists what they'd still need to buy \
        (empty if nothing). Keep both short.
        - "description" is one appetizing sentence saying what the dish is.
        - "minutes" is a realistic total time. "emoji" is one emoji. "cuisine" is a word or two ("Thai").
        - "photoSearch" is the dish's common English name, used to find a photo.
        - "message" is one short, friendly sentence. If the ingredients aren't food, return no ideas \
        and say so.
        """

    static func prompt(ingredients: [String], excluding shown: [String]) -> String {
        var prompt = "I have: \(ingredients.joined(separator: ", "))."
        if !shown.isEmpty {
            prompt += "\nI've already seen these ideas, so suggest different dishes: \(shown.joined(separator: ", "))."
        }
        return prompt
    }

    /// `preferences` is the user's diet and allergies (`Account.chefNote`), or "".
    func suggest(ingredients: [String], excluding shown: [String] = [], preferences: String = "") async throws -> Result {
        var prompt = Self.prompt(ingredients: ingredients, excluding: shown)
        if !preferences.isEmpty { prompt += "\n\nAbout me: \(preferences)" }
        return try await client.send(
            system: Self.systemPrompt,
            content: [.text(prompt)],
            schema: Self.schema,
            as: Result.self
        )
    }
}
