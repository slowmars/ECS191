import Foundation

/// Finds a real photo of a dish for AI-written recipes (Claude writes text, not images).
///
/// It tries TheMealDB first (consistent, styled food photos), then the lead image of the dish's
/// Wikipedia article (Wikimedia Commons, free licenses), and keeps the credit either way.
/// The photo shows the dish, not this exact recipe.
struct PhotoFinder: Sendable {
    struct Photo: Sendable, Equatable {
        let url: String
        let credit: String
    }

    typealias Transport = @Sendable (URL) async throws -> Data
    var transport: Transport = { url in
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Cookd/1.0 (iOS meal-planning app)", forHTTPHeaderField: "User-Agent")
        return try await URLSession.shared.data(for: request).0
    }

    func find(_ dish: String) async -> Photo? {
        let query = dish.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }
        if let photo = await fromMealDB(query) { return photo }
        if let photo = await fromWikipedia(query) { return photo }
        // "Spinach and cheddar frittata" is too specific; the dish type ("Frittata") still looks right.
        let words = query.split(separator: " ")
        guard words.count > 1, let last = words.last, last.count > 3 else { return nil }
        return await fromWikipedia(String(last))
    }

    private func fromMealDB(_ query: String) async -> Photo? {
        var components = URLComponents(string: "https://www.themealdb.com/api/json/v1/1/search.php")!
        components.queryItems = [URLQueryItem(name: "s", value: query)]
        guard let url = components.url, let data = try? await transport(url),
              let json = try? JSONDecoder().decode(JSONValue.self, from: data),
              case .array(let meals) = json["meals"] else { return nil }
        // Only accept a close match, so "chicken curry" doesn't show a random chicken dish.
        let wanted = RecipeMatcher.tokens(query)
        for meal in meals {
            guard case .string(let name) = meal["strMeal"], case .string(let thumb) = meal["strMealThumb"] else { continue }
            let tokens = RecipeMatcher.tokens(name)
            if wanted.isSubset(of: tokens) || tokens.isSubset(of: wanted) {
                return Photo(url: thumb, credit: "Photo: TheMealDB")
            }
        }
        return nil
    }

    private func fromWikipedia(_ query: String) async -> Photo? {
        var components = URLComponents(string: "https://en.wikipedia.org/w/api.php")!
        // Search rather than exact titles: "Chicken burrito" finds the "Burrito" article,
        // "Spinach and cheddar frittata" finds "Frittata".
        components.queryItems = [
            .init(name: "action", value: "query"), .init(name: "generator", value: "search"),
            .init(name: "gsrsearch", value: query + " food"), .init(name: "gsrlimit", value: "3"),
            .init(name: "prop", value: "pageimages"), .init(name: "piprop", value: "name"),
            .init(name: "format", value: "json"), .init(name: "formatversion", value: "2"),
        ]
        guard let url = components.url, let data = try? await transport(url),
              let json = try? JSONDecoder().decode(JSONValue.self, from: data),
              case .array(let pages) = json["query"]?["pages"] else { return nil }
        // Best-ranked result that has a photo.
        let ranked = pages.sorted {
            if case .number(let a) = $0["index"], case .number(let b) = $1["index"] { return a < b }
            return false
        }
        guard let file = ranked.lazy.compactMap({ page -> String? in
            if case .string(let name) = page["pageimage"] { return name }
            return nil
        }).first else { return nil }

        var info = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
        info.queryItems = [
            .init(name: "action", value: "query"), .init(name: "titles", value: "File:" + file),
            .init(name: "prop", value: "imageinfo"), .init(name: "iiprop", value: "url|extmetadata"),
            .init(name: "iiurlwidth", value: "900"), .init(name: "format", value: "json"), .init(name: "formatversion", value: "2"),
        ]
        guard let infoURL = info.url, let infoData = try? await transport(infoURL),
              let infoJSON = try? JSONDecoder().decode(JSONValue.self, from: infoData),
              case .array(let filePages) = infoJSON["query"]?["pages"],
              case .array(let imageInfo) = filePages.first?["imageinfo"], let first = imageInfo.first,
              case .string(let thumb) = first["thumburl"] else { return nil }

        let meta = first["extmetadata"]
        guard case .string(let license) = meta?["LicenseShortName"]?["value"],
              ["CC", "Public domain", "GFDL"].contains(where: license.hasPrefix) else { return nil }
        var artist = "Unknown"
        if case .string(let html) = meta?["Artist"]?["value"] {
            artist = Self.artistName(fromHTML: html)
        }
        return Photo(url: thumb, credit: "Photo: \(artist), \(license), Wikimedia Commons")
    }

    /// Commons credits are HTML, sometimes a whole table with an email and camera details.
    /// The name is usually the first link's text; otherwise the first non-empty line.
    static func artistName(fromHTML html: String) -> String {
        if let match = html.firstMatch(of: #/<a[^>]*>([^<]+)</a>/#) {
            let name = String(match.1).trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { return String(name.prefix(60)) }
        }
        let text = html.replacingOccurrences(of: "<[^>]+>", with: "\n", options: .regularExpression)
        let line = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        return line.isEmpty ? "Unknown" : String(line.prefix(60))
    }
}
