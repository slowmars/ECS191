import Foundation

/// Finds cooking ingredients in a photo of a fridge, pantry or countertop.
///
/// No custom model training is needed: Claude's vision already recognizes food. Accuracy comes from
///  1. a focused prompt with clear rules (read labels, don't guess hidden items),
///  2. mapping what it sees onto the app's own ingredient names, so matches line up with recipes,
///  3. listing only what's clearly visible (a confidence level per item; guesses are dropped), and
///  4. the user reviewing and fixing the list before anything else happens.
struct IngredientScanner: Sendable {
    struct DetectedIngredient: Codable, Hashable, Sendable {
        enum Confidence: String, Codable, Sendable { case high, medium, low }
        var name: String
        var confidence: Confidence
    }

    struct Result: Codable, Sendable {
        var ingredients: [DetectedIngredient]
        /// One short sentence about what was found (or why nothing was).
        var message: String
    }

    let client: ClaudeClient

    static let schema = Schema.object([
        "ingredients": Schema.array(of: Schema.object([
            "name": Schema.string,
            "confidence": Schema.oneOf(["high", "medium"]),
        ])),
        "message": Schema.string,
    ])

    static func systemPrompt(knownIngredients: [String]) -> String {
        """
        You identify cooking ingredients in photos for Cookd, a meal-planning app for home cooks \
        in the US. The photo usually shows the inside of a fridge, a pantry shelf, a countertop or a \
        grocery haul. The list you return is used to suggest recipes the person can cook, so accuracy \
        matters more than length.

        Rules:
        - Only list ingredients you can actually see and identify in this photo. Never add items \
        because they're common in fridges or pantries. Jam, jelly, grapes, berries, condiments, \
        butter and milk are the usual mistakes: include them only when you can clearly see the item \
        itself or read its label.
        - Things that look alike are easy to mix up: a jar of red or purple food could be jam, salsa, \
        pasta sauce or pickled beets; small round fruit could be grapes, cherry tomatoes, olives or \
        berries. If you can't tell which it is, leave it out.
        - List each distinct ingredient once, even if there are several of it.
        - If an item matches one of the app's ingredients below, use that exact name. For example, a \
        block or bag of cheddar is "Shredded cheddar" or "Cheddar slices" depending on what it looks like, \
        and raw chicken breasts are "Chicken breast". Otherwise use a short, everyday grocery name, \
        such as "Spinach" rather than "Organic baby spinach leaves".
        - Read the labels on packages, cans, jars and bottles to identify them. If a container is \
        opaque and unlabeled, leave it out instead of guessing.
        - List ingredients, not prepared dishes. Leftovers in closed containers don't count.
        - Leave out non-food items, and drinks unless they're used for cooking (milk and broth count, soda doesn't).
        - confidence: "high" means clearly visible and identifiable; "medium" means you can see the item \
        and are fairly sure, but it's partly hidden or the label is hard to read. If you're less sure \
        than that, leave it out: the person can add anything you missed, but wrong items lead to \
        wrong recipes.
        - Before answering, look at the photo again and remove anything you can't point to.
        - message: one short, friendly sentence about what you found. If the photo has no food in it, \
        return an empty list and say so.

        The app's ingredients:
        \(knownIngredients.joined(separator: ", "))
        """
    }

    func scan(jpegBase64: String, knownIngredients: [String]) async throws -> Result {
        var result = try await client.send(
            system: Self.systemPrompt(knownIngredients: knownIngredients),
            content: [
                .jpeg(base64: jpegBase64),
                .text("What cooking ingredients are in this photo?"),
            ],
            schema: Self.schema,
            as: Result.self
        )
        // Guesses do more harm than good (they suggest recipes you can't make), so drop any that slip through.
        result.ingredients.removeAll { $0.confidence == .low }
        return result
    }
}
