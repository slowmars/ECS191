import SwiftUI

/// A set of recipes the user can open as a full grid ("See all").
struct RecipeCollection: Hashable {
    enum Kind: Hashable {
        case quick, balanced, world, saved
        case category(String)
    }

    let title: String
    let kind: Kind

    @MainActor
    func recipes(in library: RecipeLibrary) -> [Recipe] {
        switch kind {
        case .quick:
            library.bundled.filter { $0.minutes <= 25 && $0.category != "Desserts" }
        case .balanced:
            library.bundled.filter { library.catalog.tags(for: $0).contains(.balanced) }
        case .world:
            library.filtered(category: RecipeCategory.world, query: "")
        case .saved:
            library.saved
        case .category(let category):
            library.filtered(category: category, query: "")
        }
    }
}

/// The Recipes tab: browse by shelves instead of one long list.
///
/// Design notes:
/// - Horizontal shelves (familiar from the App Store and streaming apps, per Jakob's law) let people
///   skim many dishes without an endless vertical list.
/// - Each shelf shows at most 10 cards and a "See all" (Miller's law, Hick's law: small, chunked choices).
/// - A featured carousel leads with balanced meals, so the healthiest choice is the easiest one.
struct RecipesView: View {
    @Environment(RecipeLibrary.self) private var library
    @Environment(MealPlan.self) private var plan
    @Environment(Router.self) private var router
    @Environment(AccountStore.self) private var accounts
    @State private var query = ""
    @State private var showingSettings = false
    /// Sign out or delete, run once Settings has finished closing (see SettingsView).
    @State private var afterSettings: (() -> Void)?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    discover
                } else {
                    SearchResults(query: query)
                }
            }
            .background(Color(.systemGroupedBackground))
            // The logo and name replace the "Recipes" title (which still labels the back button).
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(removing: .title)
            .searchable(text: $query, prompt: "Dishes, cuisines, ingredients")
            .navigationDestination(for: Recipe.self) { RecipeDetailView(recipe: $0) }
            .navigationDestination(for: RecipeCollection.self) { RecipeGridView(collection: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CookdWordmark(size: 26)
                        .fixedSize()
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { showingSettings = true }
                }
            }
            .sheet(isPresented: $showingSettings, onDismiss: {
                afterSettings?()
                afterSettings = nil
            }) {
                SettingsView(afterClose: $afterSettings)
            }
            #if DEBUG
            // `-openSettings YES` opens Settings at launch (used for simulator screenshots).
            .onAppear { if UserDefaults.standard.bool(forKey: "openSettings") { showingSettings = true } }
            .onAppear { if let recipe = router.debugRecipe { router.debugRecipe = nil; path.append(recipe) } }
            #endif
        }
    }

    // MARK: Discover

    private var discover: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxl) {
            // Re-checked every minute, so the greeting changes from morning to night while the app is open.
            TimelineView(.everyMinute) { context in
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.greeting(at: context.date, name: accounts.current?.firstName ?? ""))
                        .font(Theme.heading(.title2))
                    Text("What are we cooking this week?")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.bottom, -Theme.Space.s)

            dietFilter
                .padding(.bottom, -Theme.Space.s)

            if !plan.entries.isEmpty { planBanner }

            if !featured.isEmpty {
                FeaturedCarousel(recipes: featured, subtitle: featuredSubtitle)
            }

            if !library.saved.isEmpty {
                shelf(RecipeCollection(title: "Your recipes", kind: .saved), subtitle: "Saved from Chef AI")
            }
            shelf(RecipeCollection(title: "Quick & easy", kind: .quick), subtitle: "Ready in 25 minutes or less")
            shelf(RecipeCollection(title: "Healthy & balanced", kind: .balanced), subtitle: "Protein, carbs and fat in good proportion")
            shelf(RecipeCollection(title: "World flavors", kind: .world), subtitle: "Famous dishes from 11 cuisines")
            categories
        }
        .padding(.vertical, Theme.Space.l)
    }

    /// "Good morning, Alex" (5 am to noon), "Good afternoon" (to 5 pm), otherwise "Good evening".
    static func greeting(at date: Date, name: String) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        let part = switch hour {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
        return name.isEmpty ? part : "\(part), \(name)"
    }

    /// Balanced meals that pass the diet filter, rotating daily so the app feels fresh.
    /// If a filter leaves no balanced meal, any main dish that fits will do.
    private var featured: [Recipe] {
        var pool = RecipeCollection(title: "", kind: .balanced).recipes(in: library).filter(accounts.shows)
        if pool.isEmpty { pool = library.bundled.filter { $0.category != "Desserts" && accounts.shows($0) } }
        guard !pool.isEmpty else { return [] }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        let picks = (0..<min(5, pool.count)).map { pool[(day + $0 * 3) % pool.count] }
        return picks.reduce(into: []) { unique, recipe in if !unique.contains(recipe) { unique.append(recipe) } }
    }

    private var featuredSubtitle: String {
        guard let diet = accounts.current?.dietFilter else { return "Balanced meals chosen for today" }
        return "Balanced \(diet.shortName.lowercased()) meals chosen for today"
    }

    /// Diet filter chips. Nothing is selected at first, so every recipe shows. Tap a chip to filter;
    /// tap it again (or Clear) to show everything. The choice also shapes Tonight's picks and Chef AI,
    /// and is saved with the account.
    private var dietFilter: some View {
        let current = accounts.current?.dietFilter
        return VStack(alignment: .leading, spacing: Theme.Space.s) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.s) {
                    ForEach(Diet.allCases) { diet in
                        DietChip(diet: diet, isSelected: diet == current) {
                            setFilter(diet == current ? nil : diet)
                        }
                    }
                }
            }
            .contentMargins(.horizontal, Theme.Space.l, for: .scrollContent)
            .scrollClipDisabled()

            if let current {
                let count = library.recipes.count(where: accounts.shows)
                HStack(spacing: Theme.Space.xs) {
                    Text("\(count) \(current.shortName.lowercased()) recipe\(count == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.tertiary)
                    Button("Clear") { setFilter(nil) }
                        .fontWeight(.semibold)
                        .accessibilityLabel("Clear diet filter")
                }
                .font(.subheadline)
                .padding(.horizontal, Theme.Space.l)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .sensoryFeedback(.selection, trigger: current)
    }

    private func setFilter(_ diet: Diet?) {
        withAnimation(.snappy) { accounts.update { $0.dietFilter = diet } }
    }

    /// Picks up where the user left off (Zeigarnik effect): an unfinished plan stays in view.
    private var planBanner: some View {
        let toCook = plan.entries.count - plan.cookedCount
        return Button {
            router.tab = .plan
        } label: {
            HStack(spacing: Theme.Space.m) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(toCook == 0 ? "Everything's cooked!" : "\(toCook) meal\(toCook == 1 ? "" : "s") left to cook")
                        .font(.headline)
                    Text("Open your plan")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .cardStyle()
        }
        .buttonStyle(.pressable)
        .foregroundStyle(.primary)
        .padding(.horizontal, Theme.Space.l)
    }

    @ViewBuilder
    private func shelf(_ collection: RecipeCollection, subtitle: String) -> some View {
        let recipes = collection.recipes(in: library).filter(accounts.shows)
        if !recipes.isEmpty {
            shelf(collection, subtitle: subtitle, recipes: recipes)
        }
    }

    private func shelf(_ collection: RecipeCollection, subtitle: String, recipes: [Recipe]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            SectionHeader(title: collection.title, subtitle: subtitle) {
                if recipes.count > 10 {
                    NavigationLink("See all", value: collection)
                        .font(.subheadline.weight(.semibold))
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: Theme.Space.m) {
                    ForEach(recipes.prefix(10)) { RecipeCard(recipe: $0) }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, Theme.Space.l, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
        }
    }

    private var categories: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            SectionHeader(title: "Browse by category")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Theme.Space.m) {
                    // No "Vegetarian" tile: the diet filter above already covers it.
                    ForEach(RecipeCategory.all.filter { $0 != "Vegetarian" }, id: \.self) { category in
                        if let cover = library.bundled.first(where: { $0.category == category && accounts.shows($0) }) {
                            CategoryTile(category: category, cover: cover)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, Theme.Space.l, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
        }
    }
}

// MARK: - Featured carousel

/// Full-width, paging hero cards. The one place with big imagery, so it stands out (von Restorff effect).
private struct FeaturedCarousel: View {
    let recipes: [Recipe]
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            SectionHeader(title: "Tonight's picks", subtitle: subtitle)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Theme.Space.m) {
                    ForEach(recipes) { recipe in
                        FeaturedCard(recipe: recipe)
                            .containerRelativeFrame(.horizontal) { width, _ in width - Theme.Space.l * 2 - Theme.Space.xl }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, Theme.Space.l, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
        }
    }
}

private struct FeaturedCard: View {
    let recipe: Recipe

    var body: some View {
        NavigationLink(value: recipe) {
            ZStack(alignment: .bottomLeading) {
                Color.clear
                    .frame(height: 260)
                    .overlay { RecipePhoto(recipe: recipe, emojiSize: 80) }
                    .clipped()
                // Scrim keeps white text readable on any photo (WCAG contrast).
                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 6) {
                    Text(recipe.cuisine.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(0.8)
                        .opacity(0.9)
                    Text(recipe.name)
                        .font(Theme.heading(.title2))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text("\(recipe.minutes) min · \(recipe.nutrition.calories) cal · \(recipe.nutrition.protein)g protein")
                        .font(.subheadline.weight(.medium))
                        .opacity(0.9)
                }
                .foregroundStyle(.white)
                .padding(Theme.Space.l)
            }
            .clipShape(.rect(cornerRadius: Theme.Radius.card))
            .contentShape(.rect(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.pressable)
        .overlay(alignment: .topTrailing) {
            QuickAddButton(recipe: recipe).padding(Theme.Space.s)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Featured: \(recipe.name), \(recipe.minutes) minutes")
    }
}

/// One diet filter chip: white when off, green when on.
private struct DietChip: View {
    let diet: Diet
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(diet.emoji)
                Text(diet.shortName)
                if isSelected {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.heavy))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: Theme.minTap - 4)
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .background(isSelected ? AnyShapeStyle(Color.accentColor)
                                   : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                        in: .capsule)
            .shadow(color: .black.opacity(isSelected ? 0 : 0.05), radius: 6, y: 2)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(diet.rawValue)
        .accessibilityHint(isSelected ? "Shows all recipes again" : "Shows only \(diet.rawValue.lowercased()) recipes")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct CategoryTile: View {
    let category: String
    let cover: Recipe?

    var body: some View {
        NavigationLink(value: RecipeCollection(title: category, kind: .category(category))) {
            ZStack(alignment: .bottomLeading) {
                Color.clear
                    .frame(width: 132, height: 96)
                    .overlay { if let cover { RecipePhoto(recipe: cover, emojiSize: 32) } }
                    .clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                Text(category)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(Theme.Space.s)
            }
            .clipShape(.rect(cornerRadius: Theme.Radius.small))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(category)
    }
}

// MARK: - Search

private struct SearchResults: View {
    @Environment(RecipeLibrary.self) private var library
    @Environment(Router.self) private var router
    @Environment(AccountStore.self) private var accounts
    let query: String

    var body: some View {
        let results = library.filtered(category: nil, query: query).filter(accounts.shows)
        if results.isEmpty {
            // No dead ends: hand the search to Chef AI.
            EmptyState(systemImage: "sparkles",
                       title: "No \"\(query)\" yet",
                       message: "Chef AI can write one for you, based on well-regarded recipes, in about a minute.",
                       actionTitle: "Ask Chef AI") {
                router.askChef(for: query)
            }
            .padding(.top, Theme.Space.xxl)
        } else {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                Text("\(results.count) recipe\(results.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Theme.Space.l)
                RecipeGrid(recipes: results)
            }
            .padding(.vertical, Theme.Space.m)
        }
    }
}

/// A two-column grid that adapts to larger text and iPad widths.
struct RecipeGrid: View {
    let recipes: [Recipe]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 156), spacing: Theme.Space.m, alignment: .top)],
                  spacing: Theme.Space.xl) {
            ForEach(recipes) { RecipeCard(recipe: $0, width: nil) }
        }
        .padding(.horizontal, Theme.Space.l)
    }
}

// MARK: - See all

/// Every recipe in a collection, with sorting and health filters tucked into one menu.
struct RecipeGridView: View {
    @Environment(RecipeLibrary.self) private var library
    @Environment(AccountStore.self) private var accounts
    let collection: RecipeCollection
    @State private var requiredTags: Set<RecipeTag> = []
    @State private var sort = Sort.recommended

    enum Sort: String, CaseIterable, Identifiable {
        case recommended = "Recommended"
        case quickest = "Quickest"
        case protein = "Most protein"
        case lightest = "Fewest calories"
        var id: String { rawValue }
    }

    private var recipes: [Recipe] {
        let filtered = collection.recipes(in: library).filter { recipe in
            accounts.shows(recipe)
                && (requiredTags.isEmpty || requiredTags.isSubset(of: library.catalog.tags(for: recipe)))
        }
        switch sort {
        case .recommended: return filtered
        case .quickest: return filtered.sorted { $0.minutes < $1.minutes }
        case .protein: return filtered.sorted { $0.nutrition.protein > $1.nutrition.protein }
        case .lightest: return filtered.sorted { $0.nutrition.calories < $1.nutrition.calories }
        }
    }

    var body: some View {
        let recipes = recipes
        ScrollView {
            if recipes.isEmpty {
                EmptyState(systemImage: "line.3.horizontal.decrease.circle", title: "Nothing matches",
                           message: "Try turning off a filter.", actionTitle: "Clear filters") { requiredTags = [] }
            } else {
                RecipeGrid(recipes: recipes)
                    .padding(.vertical, Theme.Space.l)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(collection.title)
        .toolbar {
            Menu {
                Picker("Sort by", selection: $sort) {
                    ForEach(Sort.allCases) { Text($0.rawValue).tag($0) }
                }
                Section("Only show") {
                    ForEach(RecipeTag.allCases) { tag in
                        Toggle(tag.rawValue, systemImage: tag.systemImage, isOn: Binding(
                            get: { requiredTags.contains(tag) },
                            set: { if $0 { requiredTags.insert(tag) } else { requiredTags.remove(tag) } }
                        ))
                    }
                }
            } label: {
                Label("Sort and filter", systemImage: requiredTags.isEmpty && sort == .recommended
                      ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
            }
        }
    }
}
