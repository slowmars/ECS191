import Foundation
import Testing
@testable import PlatePlan

struct ClaudeClientTests {
    /// A client whose network calls return a canned reply.
    static func client(status: Int = 200, body: String) -> ClaudeClient {
        var client = ClaudeClient(apiKey: "test-key")
        client.transport = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (Data(body.utf8), response)
        }
        return client
    }

    /// A Messages API reply with a thinking block before the JSON text block.
    static func reply(json: String, stopReason: String = "end_turn") -> String {
        let escaped = String(data: try! JSONEncoder().encode(json), encoding: .utf8)!
        return """
        {"content": [{"type": "thinking", "thinking": ""}, {"type": "text", "text": \(escaped)}],
         "stop_reason": "\(stopReason)"}
        """
    }

    @Test func buildsStructuredOutputRequest() throws {
        let request = try ClaudeClient(apiKey: "test-key").request(
            system: "Be helpful.",
            content: [.jpeg(base64: "abc"), .text("What's here?")],
            schema: IngredientScanner.schema
        )
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "test-key")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")

        let body = try JSONDecoder().decode(JSONValue.self, from: try #require(request.httpBody))
        #expect(body["model"] == .string("claude-opus-5-5"))
        #expect(body["output_config"]?["format"]?["type"] == .string("json_schema"))
        #expect(body["output_config"]?["format"]?["schema"]?["additionalProperties"] == .bool(false))
        guard case .array(let messages) = body["messages"], case .array(let content) = messages.first?["content"] else {
            Issue.record("messages missing")
            return
        }
        #expect(content.first?["type"] == .string("image"))
        #expect(content.first?["source"]?["media_type"] == .string("image/jpeg"))
    }

    @Test func scannerDecodesIngredients() async throws {
        let json = #"{"ingredients": [{"name": "Eggs", "confidence": "high"}, {"name": "Spinach", "confidence": "medium"}, {"name": "Grapes", "confidence": "low"}], "message": "Found 2 things."}"#
        let scanner = IngredientScanner(client: Self.client(body: Self.reply(json: json)))
        let result = try await scanner.scan(jpegBase64: "abc", knownIngredients: ["Eggs"])
        // Low-confidence guesses are dropped.
        #expect(result.ingredients.map(\.name) == ["Eggs", "Spinach"])
        #expect(result.ingredients[1].confidence == .medium)
    }

    @Test func generatorBuildsRecipe() async throws {
        let json = """
        {"message": "Here you go!", "recipe": {"name": "Chicken Tikka Masala", "emoji": "🍛", "category": "Chicken", "cuisine": "Indian",
         "minutes": 40, "difficulty": "Easy", "servings": 2,
         "nutrition": {"calories": 520, "protein": 38, "carbs": 30, "fat": 26},
         "ingredients": [{"name": "Chicken breast", "amount": 1, "unit": "lb", "note": "cubed", "aisle": "Meat & Seafood", "isStaple": false},
                         {"name": "Salt", "amount": null, "unit": "", "note": "to taste", "aisle": "Pantry Staples", "isStaple": true}],
         "steps": ["Brown the chicken.", "Simmer in sauce."],
         "sources": ["https://www.example.com/tikka"], "photoSearch": "Chicken tikka masala"}}
        """
        let generator = RecipeGenerator(client: Self.client(body: Self.reply(json: json)))
        let output = try await generator.generate(.dish("tikka masala"), knownIngredients: [])
        let recipe = try #require(output.recipe)
        #expect(recipe.name == "Chicken Tikka Masala")
        #expect(recipe.isCustom)
        #expect(recipe.id.hasPrefix("ai-"))
        #expect(recipe.cuisine == "Indian")
        #expect(recipe.sources == ["https://www.example.com/tikka"])
        #expect(output.photoSearch == "Chicken tikka masala")
        #expect(recipe.ingredients[1].amount == nil)
    }

    @Test func generatorHandlesNonFoodRequests() async throws {
        let json = #"{"message": "I can only help with cooking.", "recipe": null}"#
        let generator = RecipeGenerator(client: Self.client(body: Self.reply(json: json)))
        let output = try await generator.generate(.dish("fix my car"), knownIngredients: [])
        #expect(output.recipe == nil)
        #expect(output.message == "I can only help with cooking.")
    }

    @Test func mapsErrors() async {
        let scanner = IngredientScanner(client: Self.client(status: 401, body: #"{"error": {"message": "invalid x-api-key"}}"#))
        await #expect(throws: ClaudeError.invalidAPIKey) {
            try await scanner.scan(jpegBase64: "abc", knownIngredients: [])
        }
        let refused = IngredientScanner(client: Self.client(body: Self.reply(json: "{}", stopReason: "refusal")))
        await #expect(throws: ClaudeError.refused) {
            try await refused.scan(jpegBase64: "abc", knownIngredients: [])
        }
    }

    @Test func schemaRequiresEveryProperty() {
        guard case .array(let required) = RecipeGenerator.schema["required"] else {
            Issue.record("no required list")
            return
        }
        #expect(Set(required) == ["message", "recipe"])
    }

    @Test func resumesAfterPausedSearch() async throws {
        // First reply pauses mid-search; the client sends the conversation back and gets the answer.
        let paused = #"{"content": [{"type": "server_tool_use", "id": "s1", "name": "web_search", "input": {"query": "x"}}], "stop_reason": "pause_turn"}"#
        let done = Self.reply(json: #"{"ingredients": [], "message": "ok"}"#)
        let calls = Counter()
        var client = ClaudeClient(apiKey: "test-key")
        client.transport = { request in
            let n = await calls.next()
            if n == 2 {
                let body = try JSONDecoder().decode(JSONValue.self, from: request.httpBody!)
                guard case .array(let messages) = body["messages"] else { throw URLError(.badServerResponse) }
                #expect(messages.count == 2)
                #expect(messages[1]["role"] == .string("assistant"))
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data((n == 1 ? paused : done).utf8), response)
        }
        let result = try await IngredientScanner(client: client).scan(jpegBase64: "abc", knownIngredients: [])
        #expect(result.message == "ok")
        #expect(await calls.value == 2)
    }

    @Test func recipeRequestsCanSearchTheWeb() throws {
        let request = try ClaudeClient(apiKey: "k").request(system: "s", content: [.text("hi")],
                                                             schema: RecipeGenerator.schema,
                                                             tools: [ClaudeClient.webSearch(maxUses: 3)])
        let body = try JSONDecoder().decode(JSONValue.self, from: try #require(request.httpBody))
        guard case .array(let tools) = body["tools"] else { Issue.record("no tools"); return }
        #expect(tools.first?["type"] == .string("web_search_20250305"))
    }
}

actor Counter {
    private(set) var value = 0
    func next() -> Int { value += 1; return value }
}

struct PhotoFinderTests {
    static func finder(mealDB: String, wikipedia: String = #"{"query": {"pages": [{}]}}"#) -> PhotoFinder {
        var finder = PhotoFinder()
        finder.transport = { url in Data((url.host()?.contains("themealdb") == true ? mealDB : wikipedia).utf8) }
        return finder
    }

    @Test func usesCloseMatchFromTheMealDB() async {
        let json = #"{"meals": [{"strMeal": "Chicken Tikka Masala", "strMealThumb": "https://x/tikka.jpg"}]}"#
        let photo = await Self.finder(mealDB: json).find("chicken tikka masala")
        #expect(photo == .init(url: "https://x/tikka.jpg", credit: "Photo: TheMealDB"))
    }

    @Test func ignoresLooseMatches() async {
        // "Chicken Handi" is a different dish; a wrong photo is worse than none.
        let json = #"{"meals": [{"strMeal": "Chicken Handi", "strMealThumb": "https://x/handi.jpg"}]}"#
        #expect(await Self.finder(mealDB: json).find("chicken tikka masala") == nil)
    }
}

struct RecipeIdeasTests {
    @Test func decodesIdeas() async throws {
        let ideas = (1...5).map { n in
            #"{"name": "Dish \#(n)", "emoji": "🍲", "cuisine": "Thai", "description": "Tasty.", "minutes": 20, "#
            + #""uses": ["Eggs"], "extras": [], "photoSearch": "Dish \#(n)"}"#
        }
        let json = #"{"message": "Here you go", "ideas": ["# + ideas.joined(separator: ",") + "]}"
        let result = try await RecipeIdeas(client: ClaudeClientTests.client(body: ClaudeClientTests.reply(json: json)))
            .suggest(ingredients: ["Eggs"])
        #expect(result.ideas.count == 5)
        #expect(result.ideas.first?.uses == ["Eggs"])
    }

    @Test func moreIdeasAvoidRepeats() {
        let prompt = RecipeIdeas.prompt(ingredients: ["Eggs", "Rice"], excluding: ["Fried Rice"])
        #expect(prompt.contains("Eggs, Rice"))
        #expect(prompt.contains("Fried Rice"))
    }

    @Test func cleansPhotoCredits() {
        let table = #"<table><tr><td><a href="x">fir0002</a> <br> someone [at] gmail.com</td></tr></table>"#
        #expect(PhotoFinder.artistName(fromHTML: table) == "fir0002")
        #expect(PhotoFinder.artistName(fromHTML: "  Jane Doe \n camera") == "Jane Doe")
        #expect(PhotoFinder.artistName(fromHTML: "") == "Unknown")
    }
}

