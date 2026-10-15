import SwiftUI

/// Credits for every recipe photo (Creative Commons licenses require them). Opened from Settings.
struct PhotoCreditsView: View {
    @Environment(RecipeLibrary.self) private var library

    private struct Credit: Decodable, Identifiable {
        let recipeId: String
        let title: String
        let author: String
        let license: String
        let source: String
        let page: String
        var id: String { recipeId }
    }

    private let credits: [Credit] = {
        guard let url = Bundle.main.url(forResource: "photo-credits", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Credit].self, from: data)) ?? []
    }()

    var body: some View {
        List {
            Section {
                ForEach(credits) { credit in
                    if let url = URL(string: credit.page) {
                        Link(destination: url) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(library.recipe(id: credit.recipeId)?.name ?? credit.recipeId)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("\(credit.author) · \(credit.license) · \(credit.source)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } footer: {
                Text("Photos from TheMealDB and Wikimedia Commons, used under the licenses shown. Tap a credit to see the original.")
            }
        }
        .navigationTitle("Photo credits")
        .navigationBarTitleDisplayMode(.inline)
    }
}
