import SwiftUI

/// Asks the AI chef for a recipe, shows it, and lets the user tweak, save or plan it.
struct AIRecipeView: View {
    @Environment(RecipeLibrary.self) private var library
    @Environment(MealPlan.self) private var plan
    @Environment(AccountStore.self) private var accounts
    let request: ChefRequest

    private enum Phase {
        case writing
        case failed(String)
        case done(Recipe, message: String)
        case declined(String)
    }

    @State private var phase = Phase.writing
    @State private var servings = 2
    @State private var tweak = ""
    @State private var isTweaking = false
    @State private var cooking: Recipe?
    @State private var showingTweak = false

    var body: some View {
        content
            .navigationTitle("Chef AI")
            .navigationBarTitleDisplayMode(.inline)
            .task { if case .writing = phase { await generate(request.generatorRequest) } }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .writing:
            WritingView(label: writingLabel)
        case .failed(let message):
            ContentUnavailableView {
                Label("Something went wrong", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") {
                    phase = .writing
                    Task { await generate(request.generatorRequest) }
                }
                .buttonStyle(.borderedProminent)
            }
        case .declined(let message):
            ContentUnavailableView("No recipe", systemImage: "fork.knife", description: Text(message))
        case .done(let recipe, let message):
            ScrollView {
                RecipeBody(recipe: recipe, servings: $servings)
                if !message.isEmpty {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Chef's note").font(.subheadline.weight(.semibold))
                            Text(message).font(.subheadline)
                        }
                    } icon: {
                        Image(systemName: "sparkles").foregroundStyle(.tint)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Space.l)
                    .background(.tint.opacity(0.1), in: .rect(cornerRadius: Theme.Radius.small))
                    .padding(.horizontal, Theme.Space.xl)
                    .padding(.bottom, Theme.Space.xl)
                }
            }
            .ignoresSafeArea(edges: .top)
            .toolbarBackground(.hidden, for: .navigationBar)
            .overlay {
                if isTweaking {
                    WritingView(label: "Updating the recipe…")
                        .background(.regularMaterial)
                }
            }
            .safeAreaInset(edge: .bottom) { actionBar(for: recipe) }
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                Button("Change something", systemImage: "wand.and.stars") { showingTweak = true }
                    .disabled(isTweaking)
            }
            .alert("Change this recipe", isPresented: $showingTweak) {
                TextField("e.g. make it vegetarian", text: $tweak)
                Button("Update") { applyTweak(to: recipe) }
                Button("Cancel", role: .cancel) { tweak = "" }
            } message: {
                Text("Tell Chef AI what to change. Everything else stays the same.")
            }
            .fullScreenCover(item: $cooking) { CookingView(recipe: $0, servings: servings) }
        }
    }

    private var writingLabel: String {
        switch request {
        case .dish(let dish): "Writing a recipe for \(dish)…"
        case .using: "Thinking up something with your ingredients…"
        case .idea(let dish, _): "Writing your \(dish) recipe…"
        }
    }

    /// Cook and Add to plan sit under the thumb. Adding also saves the recipe to "Your recipes".
    private func actionBar(for recipe: Recipe) -> some View {
        let planned = plan.contains(recipe)
        return HStack(spacing: Theme.Space.m) {
            Button {
                cooking = recipe
            } label: {
                Label("Cook", systemImage: "flame").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: 120)

            Button {
                withAnimation(.snappy) {
                    library.save(recipe)
                    plan.add(recipe, servings: servings)
                }
            } label: {
                Label(planned ? "Saved & planned" : "Save & add to plan", systemImage: planned ? "checkmark" : "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(planned)
            .sensoryFeedback(.success, trigger: planned) { _, isPlanned in isPlanned }
        }
        .controlSize(.large)
        .padding(.horizontal, Theme.Space.l)
        .padding(.vertical, Theme.Space.m)
        .background(.bar)
    }

    private func applyTweak(to recipe: Recipe) {
        let change = tweak.trimmingCharacters(in: .whitespaces)
        guard !change.isEmpty, !isTweaking else { return }
        isTweaking = true
        Task {
            await generate(.tweak(recipe, change), keepingCurrentOnFailure: true)
            isTweaking = false
            tweak = ""
        }
    }

    private func generate(_ request: RecipeGenerator.Request, keepingCurrentOnFailure: Bool = false) async {
        do {
            let client = try ClaudeClient.fromBundle()
            let output = try await RecipeGenerator(client: client)
                .generate(request, knownIngredients: library.ingredientNames,
                          preferences: accounts.current?.chefNote ?? "")
            if var recipe = output.recipe {
                // Start at 1 or 2 servings (amounts scale to match) unless they asked for a number.
                switch request {
                case _ where RecipeGenerator.asksForServings(request): servings = recipe.servings
                case .tweak: break // keep the servings they'd already picked
                default: servings = min(recipe.servings, 2)
                }
                phase = .done(recipe, message: output.message)
                // Show the recipe right away; the photo fades in when it's found.
                if let photo = await PhotoFinder().find(output.photoSearch.isEmpty ? recipe.name : output.photoSearch) {
                    recipe.photoURL = photo.url
                    recipe.photoCredit = photo.credit
                    if case .done(let shown, let message) = phase, shown.id == recipe.id {
                        phase = .done(recipe, message: message)
                    }
                }
            } else {
                phase = .declined(output.message)
            }
        } catch {
            if keepingCurrentOnFailure, case .done(let recipe, _) = phase {
                phase = .done(recipe, message: error.localizedDescription)
            } else {
                phase = .failed(error.localizedDescription)
            }
        }
    }
}

/// A calm waiting state: orbiting sparkles and short updates on what the chef is doing.
private struct WritingView: View {
    let label: String

    var body: some View {
        ChefThinkingView(title: label, steps: [
            "Looking up well-loved versions…",
            "Comparing ingredients and spices…",
            "Balancing the nutrition…",
            "Writing clear, simple steps…",
            "Double-checking times and temperatures…",
        ])
    }
}
