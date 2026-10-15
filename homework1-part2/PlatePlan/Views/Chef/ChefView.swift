import PhotosUI
import SwiftUI

/// What the Chef AI tab can navigate to.
enum ChefRoute: Hashable {
    case scan(ScanPhoto)
    case typeIngredients
    case matches([String])
    case ideas([String])
    case recipe(ChefRequest)
}

/// What to ask the AI chef to write.
enum ChefRequest: Hashable {
    case dish(String)
    case using([String])
    /// A dish the user picked from Chef AI's ideas for their ingredients.
    case idea(String, ingredients: [String])

    var generatorRequest: RecipeGenerator.Request {
        switch self {
        case .dish(let dish): .dish(dish)
        case .using(let ingredients): .using(ingredients: ingredients)
        case .idea(let dish, let ingredients): .idea(dish, have: ingredients)
        }
    }
}

/// A photo to scan. Compared by identity so it can travel in a navigation path.
struct ScanPhoto: Hashable {
    let id = UUID()
    let image: UIImage

    static func == (lhs: ScanPhoto, rhs: ScanPhoto) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// The Chef AI tab, on the far right of the tab bar where the thumb rests.
///
/// One clear primary action ("Scan my fridge") with quieter alternatives beside it, and a
/// chat-style prompt for any dish. Suggestions are tappable chips, so nobody faces a blank box.
struct ChefView: View {
    @Environment(Router.self) private var router
    @Environment(AccountStore.self) private var accounts
    @State private var path: [ChefRoute] = []
    @State private var dish = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var photoError: String?
    @FocusState private var promptFocused: Bool

    /// Ideas to tap, matched to the diet filter so nobody is offered a dish they don't eat.
    private var suggestions: [String] {
        let ideas: [String] = switch accounts.current?.dietFilter {
        case nil: ["Lemon garlic salmon", "Mushroom risotto", "Chicken fajitas"]
        case .nonVegetarian?: ["Lemon garlic salmon", "Chicken fajitas", "Korean beef bowl"]
        case .pescatarian?: ["Lemon garlic salmon", "Shrimp tacos", "Vegetarian chili"]
        case .eggetarian?: ["Mushroom risotto", "Shakshuka", "Vegetarian chili"]
        case .vegetarian?: ["Mushroom risotto", "Vegetarian chili", "Caprese pasta"]
        case .vegan?: ["Thai peanut noodles", "Vegan chili", "Crispy tofu bowl"]
        }
        return ideas + ["High-protein lunch", "Something cozy with potatoes"]
    }

    private let hasAPIKey = (try? ClaudeClient.fromBundle()) != nil
    private let hasCamera = UIImagePickerController.isSourceTypeAvailable(.camera)

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: Theme.Space.xl) {
                    if !hasAPIKey { keyBanner }
                    scanCard
                    askCard
                    Label("Photos and requests are sent to Anthropic's Claude to identify ingredients and write recipes.",
                          systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Theme.Space.l)
                }
                .padding(Theme.Space.l)
            }
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Chef AI")
            .navigationDestination(for: ChefRoute.self) { route in
                switch route {
                case .scan(let photo): ScanView(photo: photo)
                case .typeIngredients: IngredientReviewView(detected: [], message: nil)
                case .matches(let ingredients): MatchesView(ingredients: ingredients)
                case .ideas(let ingredients): RecipeIdeasView(ingredients: ingredients)
                case .recipe(let request): AIRecipeView(request: request)
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await loadPhoto(item) }
            }
            .onChange(of: router.pendingDish, initial: true) { _, pending in
                guard let pending else { return }
                router.pendingDish = nil
                path = [.recipe(.dish(pending))]
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { image in
                    path.append(.scan(ScanPhoto(image: image)))
                }
                .ignoresSafeArea()
            }
            .alert("Couldn't open that photo", isPresented: .constant(photoError != nil)) {
                Button("OK") { photoError = nil }
            } message: {
                Text(photoError ?? "")
            }
        }
    }

    private var keyBanner: some View {
        Label {
            Text("Add your Anthropic API key to **Secrets.xcconfig** and rebuild to turn on Chef AI.")
        } icon: {
            Image(systemName: "key.fill").foregroundStyle(.orange)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var scanCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 34, weight: .semibold))
                Text("What can I cook?")
                    .font(Theme.heading(.title))
                Text("Snap your fridge or counter. Chef AI lists what you have, you check it, and we find recipes you can make tonight.")
                    .font(.subheadline)
                    .opacity(0.9)
            }
            .foregroundStyle(.white)

            Group {
                if hasCamera {
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Scan my fridge", systemImage: "camera.fill").frame(maxWidth: .infinity)
                    }
                } else {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Choose a photo", systemImage: "photo.fill").frame(maxWidth: .infinity)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(Color.accentColor)
            .controlSize(.large)

            HStack(spacing: Theme.Space.m) {
                if hasCamera {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Photos", systemImage: "photo.on.rectangle").lineLimit(1).frame(maxWidth: .infinity)
                    }
                }
                NavigationLink(value: ChefRoute.typeIngredients) {
                    Label("Type them", systemImage: "keyboard").lineLimit(1).frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .controlSize(.regular)
        }
        .padding(Theme.Space.xl)
        .background(
            LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.75)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: Theme.Radius.card)
        )
        .shadow(color: Color.accentColor.opacity(0.3), radius: 16, y: 8)
    }

    private var askCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("Ask for any recipe")
                .font(Theme.heading(.title3))
            Text("Not in the app? Chef AI checks well-regarded recipes and writes a version you can save, plan and shop for.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: Theme.Space.s) {
                TextField("e.g. \(suggestions[0])", text: $dish, axis: .vertical)
                    .lineLimit(1...3)
                    .focused($promptFocused)
                    .submitLabel(.send)
                    .onSubmit(askForDish)
                Button(action: askForDish) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .frame(width: Theme.minTap, height: Theme.minTap)
                }
                .disabled(dish.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Write recipe")
            }
            .padding(.leading, Theme.Space.l)
            .padding(.vertical, 2)
            .background(Color(.tertiarySystemFill), in: .capsule)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.s) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) { path.append(.recipe(.dish(suggestion))) }
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, Theme.Space.m)
                            .padding(.vertical, Theme.Space.s)
                            .background(.tint.opacity(0.12), in: .capsule)
                            .buttonStyle(.pressable)
                    }
                }
            }
            // Chips scroll edge to edge inside the card and are clipped by it, never drawn outside.
            .contentMargins(.horizontal, Theme.Space.xl, for: .scrollContent)
            .padding(.horizontal, -Theme.Space.xl)
        }
        .cardStyle(padding: Theme.Space.xl)
    }

    private func askForDish() {
        let request = dish.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty else { return }
        promptFocused = false
        Keyboard.hide {
            path.append(.recipe(.dish(request)))
            dish = ""
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
            photoError = "Try a different photo."
            return
        }
        path.append(.scan(ScanPhoto(image: image)))
    }
}
