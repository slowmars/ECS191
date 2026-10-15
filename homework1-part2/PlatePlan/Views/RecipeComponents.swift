import SwiftUI

// MARK: - Photo

/// A recipe's photo, or a tinted emoji tile for AI recipes that don't have one.
/// Decorative for VoiceOver: the recipe name next to it carries the meaning.
struct RecipePhoto: View {
    let recipe: Recipe
    var emojiSize: CGFloat = 56

    var body: some View {
        Group {
            if let image = UIImage(named: "photo-\(recipe.id)") ?? Self.savedPhoto(for: recipe) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url = recipe.photoURL.flatMap(URL.init(string:)) {
                AsyncImage(url: url, transaction: Transaction(animation: .easeIn(duration: 0.3))) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        LinearGradient(colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.12)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay { Text(recipe.emoji).font(.system(size: emojiSize)) }
    }

    /// Photos of saved AI recipes live on disk; keep them in memory so scrolling never reads the disk.
    private static let savedPhotos = NSCache<NSString, UIImage>()

    private static func savedPhoto(for recipe: Recipe) -> UIImage? {
        guard recipe.isCustom else { return nil }
        if let cached = savedPhotos.object(forKey: recipe.id as NSString) { return cached }
        guard let image = UIImage(contentsOfFile: RecipeLibrary.photoFile(for: recipe.id).path) else { return nil }
        savedPhotos.setObject(image, forKey: recipe.id as NSString)
        return image
    }
}

// MARK: - Cards

/// A photo card for horizontal shelves and grids.
struct RecipeCard: View {
    let recipe: Recipe
    var width: CGFloat? = 168

    var body: some View {
        NavigationLink(value: recipe) {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Color.clear
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .overlay { RecipePhoto(recipe: recipe, emojiSize: 44) }
                    .clipShape(.rect(cornerRadius: Theme.Radius.photo))

                VStack(alignment: .leading, spacing: 2) {
                    Text(recipe.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)
                    Text("\(recipe.minutes) min · \(recipe.nutrition.calories) cal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: width)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .foregroundStyle(.primary)
        // The add button sits on top of the link so it gets its own taps.
        .overlay(alignment: .topTrailing) {
            QuickAddButton(recipe: recipe)
                .padding(Theme.Space.xs)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recipe.name), \(recipe.minutes) minutes, \(recipe.nutrition.calories) calories")
    }
}

/// One-tap add to plan. Big enough to hit (44 pt), with a haptic tick so it feels done.
struct QuickAddButton: View {
    @Environment(MealPlan.self) private var plan
    let recipe: Recipe

    var body: some View {
        let planned = plan.contains(recipe)
        Button {
            withAnimation(.snappy) { plan.toggle(recipe) }
        } label: {
            Image(systemName: planned ? "checkmark" : "plus")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(planned ? AnyShapeStyle(.white) : AnyShapeStyle(.tint))
                .frame(width: 32, height: 32)
                .background {
                    Circle().fill(planned ? AnyShapeStyle(.tint) : AnyShapeStyle(.regularMaterial))
                }
                .contentTransition(.symbolEffect(.replace))
                .frame(width: Theme.minTap, height: Theme.minTap)
                .contentShape(.circle)
        }
        .buttonStyle(.pressable)
        .sensoryFeedback(.success, trigger: planned) { _, isPlanned in isPlanned }
        .accessibilityLabel(planned ? "Remove \(recipe.name) from plan" : "Add \(recipe.name) to plan")
    }
}

/// A compact row with a thumbnail, used in lists.
struct RecipeThumbnailRow<Trailing: View>: View {
    let recipe: Recipe
    let subtitle: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            RecipePhoto(recipe: recipe, emojiSize: 28)
                .frame(width: 60, height: 60)
                .clipShape(.rect(cornerRadius: Theme.Radius.small))
            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.name)
                    .font(.headline)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            trailing
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Small pieces

struct SectionHeader<Action: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var action: Action

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.heading(.title3))
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityAddTraits(.isHeader)
            Spacer()
            action
        }
        .padding(.horizontal, Theme.Space.l)
    }
}

extension SectionHeader where Action == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// "40 min", "620 cal" chips under a recipe title.
struct StatPill: View {
    let systemImage: String
    let text: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, Theme.Space.m)
            .padding(.vertical, Theme.Space.s)
            .background(.fill.tertiary, in: .capsule)
    }
}

/// Small capsules like "Balanced" and "High protein".
struct RecipeTags: View {
    let tags: [RecipeTag]
    var limit = Int.max

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tags.prefix(limit)) { tag in
                Label(tag.rawValue, systemImage: tag.systemImage)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, Theme.Space.s)
                    .padding(.vertical, 4)
                    .background(.tint.opacity(0.12), in: .capsule)
                    .foregroundStyle(.tint)
            }
        }
    }
}

/// A − n + control with large tap targets.
struct ServingsControl: View {
    @Binding var servings: Int

    var body: some View {
        HStack(spacing: 0) {
            Button {
                servings = max(1, servings - 1)
            } label: {
                Image(systemName: "minus").frame(width: Theme.minTap, height: Theme.minTap)
            }
            .disabled(servings <= 1)
            .accessibilityLabel("Fewer servings")

            Text("\(servings)")
                .font(.headline.monospacedDigit())
                .frame(minWidth: 28)
                .contentTransition(.numericText())
                .accessibilityHidden(true)

            Button {
                servings = min(24, servings + 1)
            } label: {
                Image(systemName: "plus").frame(width: Theme.minTap, height: Theme.minTap)
            }
            .disabled(servings >= 24)
            .accessibilityLabel("More servings")
        }
        // Inside a List row, plain buttons all fire together on any tap (so − and + cancel out).
        // Borderless buttons each get their own tap area.
        .buttonStyle(.borderless)
        .font(.body.weight(.semibold))
        .background(.fill.tertiary, in: .capsule)
        .sensoryFeedback(.selection, trigger: servings)
        .animation(.snappy, value: servings)
        .accessibilityElement(children: .contain)
        .accessibilityValue("\(servings) servings")
    }
}

/// A friendly empty screen with one clear next step.
struct EmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 96, height: 96)
                .background(.tint.opacity(0.12), in: .circle)
            Text(title)
                .font(Theme.heading(.title2))
                .multilineTextAlignment(.center)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, Theme.Space.s)
            }
        }
        .padding(Theme.Space.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Recipe page body

/// The recipe page: a big photo, the key facts, servings, then ingredients / steps / nutrition.
/// Shared by bundled recipes and AI-written ones.
struct RecipeBody: View {
    @Environment(RecipeLibrary.self) private var library
    let recipe: Recipe
    @Binding var servings: Int
    @State private var section = Section.ingredients

    enum Section: String, CaseIterable, Identifiable {
        case ingredients = "Ingredients"
        case steps = "Steps"
        case nutrition = "Nutrition"
        var id: String { rawValue }
    }

    private var factor: Double { Double(servings) / Double(max(recipe.servings, 1)) }

    var body: some View {
        VStack(spacing: 0) {
            StretchyPhoto(recipe: recipe)

            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                titleBlock
                servingsRow
                Picker("Show", selection: $section) {
                    ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch section {
                case .ingredients: ingredients
                case .steps: steps
                case .nutrition: nutrition
                }
            }
            .padding(Theme.Space.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground),
                        in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
            .offset(y: -28)
            .padding(.bottom, -28)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("\(recipe.cuisine) · \(recipe.category)".uppercased())
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.tint)
            Text(recipe.name)
                .font(Theme.heading(.largeTitle))
                .fixedSize(horizontal: false, vertical: true)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.s) {
                    StatPill(systemImage: "clock", text: "\(recipe.minutes) min")
                    StatPill(systemImage: "flame", text: "\(recipe.nutrition.calories) cal")
                    StatPill(systemImage: "bolt", text: "\(recipe.nutrition.protein)g protein")
                    StatPill(systemImage: "chart.bar", text: recipe.difficulty)
                }
            }
            .scrollClipDisabled()
            let tags = library.catalog.tags(for: recipe)
            if !tags.isEmpty { RecipeTags(tags: tags) }
            if !recipe.sources.isEmpty { sourcesView }
            if let credit = recipe.photoCredit {
                Text(credit + ". Shows the dish, not this exact recipe.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// Where an AI recipe came from, so people can trust (and check) it.
    private var sourcesView: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Label("Based on these recipes", systemImage: "checkmark.seal")
                .font(.subheadline.weight(.semibold))
            ForEach(recipe.sources.prefix(4), id: \.self) { source in
                if let url = URL(string: source), let host = url.host() {
                    Link(host.replacingOccurrences(of: "www.", with: ""), destination: url)
                        .font(.subheadline)
                }
            }
        }
        .padding(Theme.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.tint.opacity(0.08), in: .rect(cornerRadius: Theme.Radius.small))
    }

    private var servingsRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Servings").font(.headline)
                Text(servings == recipe.servings ? "As written" : "Scaled from \(recipe.servings)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ServingsControl(servings: $servings)
        }
        .padding(Theme.Space.m)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: Theme.Radius.small))
    }

    private var ingredients: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.m) {
                    Text(ingredient.amount(scaledBy: factor)?.formatted ?? "")
                        .font(.body.weight(.semibold))
                        .frame(width: 88, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ingredient.name)
                        if !ingredient.note.isEmpty {
                            Text(ingredient.note)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, Theme.Space.m)
                .accessibilityElement(children: .combine)
                if index < recipe.ingredients.count - 1 { Divider() }
            }
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: Theme.Space.m) {
                    Text("\(index + 1)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(.tint, in: .circle)
                    Text(step)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
            if servings != recipe.servings {
                Label("Amounts in the steps are for \(recipe.servings) servings. Use the scaled ingredient list.",
                      systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var nutrition: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Grid(horizontalSpacing: Theme.Space.m, verticalSpacing: Theme.Space.m) {
                GridRow {
                    nutrient("\(recipe.nutrition.calories)", "Calories")
                    nutrient("\(recipe.nutrition.protein)g", "Protein")
                }
                GridRow {
                    nutrient("\(recipe.nutrition.carbs)g", "Carbs")
                    nutrient("\(recipe.nutrition.fat)g", "Fat")
                }
            }
            Text("Estimated per serving.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func nutrient(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.heading(.title2))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.l)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: Theme.Radius.small))
        .accessibilityElement(children: .combine)
    }
}

/// The hero photo at the top of a recipe. Pulling down stretches it instead of showing a gap.
struct StretchyPhoto: View {
    let recipe: Recipe
    var height: CGFloat = 340

    var body: some View {
        GeometryReader { proxy in
            let pull = max(0, proxy.frame(in: .scrollView).minY)
            RecipePhoto(recipe: recipe, emojiSize: 96)
                .frame(width: proxy.size.width, height: height + pull)
                .clipped()
                .offset(y: -pull)
        }
        .frame(height: height)
    }
}
