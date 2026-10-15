import SwiftUI

/// The dishes you could make from what you have (as many as genuinely work). Tap one for the full recipe.
struct RecipeIdeasView: View {
    @Environment(AccountStore.self) private var accounts
    let ingredients: [String]

    private enum Phase {
        case loading
        case failed(String)
        case loaded(message: String)
    }

    @State private var phase = Phase.loading
    @State private var ideas: [RecipeIdeas.Idea] = []
    @State private var photos: [String: PhotoFinder.Photo] = [:]
    @State private var loadingMore = false

    var body: some View {
        Group {
            switch phase {
            case .loading:
                waiting
            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn't get ideas", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try again") { Task { await load() } }
                        .buttonStyle(.borderedProminent)
                }
            case .loaded(let message):
                list(message: message)
            }
        }
        .navigationTitle("Ideas for you")
        .navigationBarTitleDisplayMode(.inline)
        .task { if ideas.isEmpty { await load() } }
    }

    private var waiting: some View {
        ChefThinkingView(title: "Finding dishes you can make…", steps: [
            "Reading your ingredients…",
            "Thinking across cuisines…",
            "Picking the best fits…",
        ])
    }

    private func list(message: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                if !message.isEmpty {
                    Label(message, systemImage: "sparkles")
                        .font(.subheadline)
                        .padding(.horizontal, Theme.Space.l)
                }
                ForEach(ideas) { idea in
                    NavigationLink(value: ChefRoute.recipe(.idea(idea.name, ingredients: ingredients))) {
                        IdeaCard(idea: idea, photo: photos[idea.id])
                    }
                    .buttonStyle(.pressable)
                    .padding(.horizontal, Theme.Space.l)
                }
                Button {
                    Task { await loadMore() }
                } label: {
                    Label(loadingMore ? "Finding more…" : "More ideas", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(loadingMore)
                .padding(.horizontal, Theme.Space.l)
            }
            .padding(.vertical, Theme.Space.l)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func load() async {
        phase = .loading
        do {
            let result = try await RecipeIdeas(client: ClaudeClient.fromBundle())
                .suggest(ingredients: ingredients, preferences: accounts.current?.chefNote ?? "")
            ideas = result.ideas
            phase = .loaded(message: result.message)
            await findPhotos(for: result.ideas)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func loadMore() async {
        loadingMore = true
        defer { loadingMore = false }
        guard let result = try? await RecipeIdeas(client: ClaudeClient.fromBundle())
            .suggest(ingredients: ingredients, excluding: ideas.map(\.name),
                     preferences: accounts.current?.chefNote ?? "") else { return }
        let new = result.ideas.filter { idea in !ideas.contains { $0.id == idea.id } }
        withAnimation { ideas += new }
        await findPhotos(for: new)
    }

    /// Photos load in parallel and fade in as they arrive; the cards are usable before then.
    private func findPhotos(for ideas: [RecipeIdeas.Idea]) async {
        await withTaskGroup(of: (String, PhotoFinder.Photo?).self) { group in
            for idea in ideas {
                group.addTask { (idea.id, await PhotoFinder().find(idea.photoSearch.isEmpty ? idea.name : idea.photoSearch)) }
            }
            for await (id, photo) in group {
                if let photo { withAnimation { photos[id] = photo } }
            }
        }
    }
}

private struct IdeaCard: View {
    let idea: RecipeIdeas.Idea
    let photo: PhotoFinder.Photo?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(height: 150)
                .overlay { image }
                .clipped()

            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text("\(idea.cuisine.uppercased()) · \(idea.minutes) MIN")
                    .font(.caption.weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(.tint)
                Text(idea.name)
                    .font(Theme.heading(.title3))
                    .multilineTextAlignment(.leading)
                Text(idea.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                if !idea.uses.isEmpty {
                    Label("Uses your " + idea.uses.map { $0.lowercased() }.joined(separator: ", "),
                          systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tint)
                }
                Label(idea.extras.isEmpty ? "Nothing extra to buy" : "Also need: " + idea.extras.joined(separator: ", "),
                      systemImage: idea.extras.isEmpty ? "cart" : "cart.badge.plus")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(idea.extras.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange))
                if let photo {
                    Text(photo.credit)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .padding(Theme.Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: Theme.Radius.card))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        .foregroundStyle(.primary)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the full recipe")
    }

    @ViewBuilder
    private var image: some View {
        if let url = photo.flatMap({ URL(string: $0.url) }) {
            AsyncImage(url: url) { phase in
                if let image = phase.image { image.resizable().scaledToFill() } else { placeholder }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        LinearGradient(colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.12)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay { Text(idea.emoji).font(.system(size: 56)) }
    }
}
