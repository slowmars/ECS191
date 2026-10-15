import AuthenticationServices
import SwiftUI

/// Where sign-in can go next.
enum AuthRoute: Hashable {
    case email
    case phone
    /// A new account that still needs a name.
    case name(NewAccount)
}

/// Someone who's verified who they are but hasn't told us their name yet.
struct NewAccount: Hashable {
    let id: String
    let method: Account.Method
    let contact: String
    var suggestedName = ""
}

/// The first screen for anyone signed out: real food up top, then one tap to get in.
///
/// Sign in with Apple leads (it's the fastest and the App Store requires it next to Google);
/// email and phone are quieter buttons below, so there's one clear primary choice.
struct LoginView: View {
    @Environment(AccountStore.self) private var accounts
    @Environment(\.colorScheme) private var colorScheme
    @State private var path: [AuthRoute] = []
    @State private var notice: Notice?

    private struct Notice: Identifiable {
        let title: String
        let message: String
        var id: String { title }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: Theme.Space.xl) {
                    PhotoMosaic()
                        .padding(.bottom, -Theme.Space.xxl)

                    VStack(spacing: Theme.Space.s) {
                        CookdWordmark(size: 44)
                            .padding(.bottom, Theme.Space.xs)
                        Text("Not cooked. Cooking.")
                            .font(Theme.heading(.title3, weight: .semibold))
                        Text("Plan meals, shop once, and cook step by step.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, Theme.Space.xl)

                    VStack(spacing: Theme.Space.m) {
                        SignInWithAppleButton(.continue) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            handleApple(result)
                        }
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .frame(height: 52)
                        .clipShape(.capsule)

                        Button {
                            notice = Notice(title: "Google sign-in is coming soon",
                                            message: "For now, continue with Apple, email or phone.")
                        } label: {
                            AuthButtonLabel(title: "Continue with Google", systemImage: "g.circle.fill")
                        }
                        .buttonStyle(AuthButtonStyle())

                        HStack(spacing: Theme.Space.m) {
                            NavigationLink(value: AuthRoute.email) {
                                AuthButtonLabel(title: "Email", systemImage: "envelope.fill")
                            }
                            NavigationLink(value: AuthRoute.phone) {
                                AuthButtonLabel(title: "Phone", systemImage: "phone.fill")
                            }
                        }
                        .buttonStyle(AuthButtonStyle())
                    }
                    .padding(.horizontal, Theme.Space.xl)

                    Text("By continuing, you agree to Cookd's Terms of Use and Privacy Policy. We never post anything or share your data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Space.xxl)
                }
                .padding(.bottom, Theme.Space.xl)
            }
            .scrollBounceBehavior(.basedOnSize)
            .ignoresSafeArea(edges: .top)
            .background(Color(.systemGroupedBackground))
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .email: EmailSignInView()
                case .phone: PhoneSignInView(path: $path)
                case .name(let account): NameStepView(account: account)
                }
            }
            .alert(item: $notice) { notice in
                Alert(title: Text(notice.title), message: Text(notice.message))
            }
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            let id = "apple:" + credential.user
            let name = credential.fullName.map { PersonNameComponentsFormatter().string(from: $0) } ?? ""
            let email = credential.email ?? ""
            if let existing = accounts.existing(id) {
                accounts.signIn(id: existing.id, method: .apple, name: existing.name, contact: email)
            } else {
                // Apple only shares a name the first time, so confirm it (or ask for one) before going in.
                path.append(.name(NewAccount(id: id, method: .apple, contact: email, suggestedName: name)))
            }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            notice = Notice(title: "Couldn't sign in with Apple",
                            message: "Check that you're signed in to your Apple Account in iOS Settings, then try again. You can also continue with email or phone.")
        }
    }
}

// MARK: - Name

/// Asks a new user what to call them; the home screen greets them by this name.
struct NameStepView: View {
    @Environment(AccountStore.self) private var accounts
    let account: NewAccount
    @State private var name: String
    @FocusState private var focused: Bool

    init(account: NewAccount) {
        self.account = account
        _name = State(initialValue: account.suggestedName)
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        AuthScreen(emoji: "👋", title: "What should we call you?",
                   subtitle: "We'll use it to say hi when you open the app.") {
            AuthField(systemImage: "person.fill") {
                TextField("Your name", text: $name)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.continue)
                    .focused($focused)
                    .onSubmit(finish)
            }
            Button(action: finish) {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(trimmed.isEmpty)
        }
        .onAppear { focused = true }
    }

    private func finish() {
        guard !trimmed.isEmpty else { return }
        let name = trimmed
        Keyboard.hide {
            accounts.signIn(id: account.id, method: account.method, name: name, contact: account.contact)
        }
    }
}

// MARK: - Shared pieces

/// The layout every sign-in step uses: an emoji, a title, a line of help, then the form.
struct AuthScreen<Content: View>: View {
    let emoji: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    Text(emoji)
                        .font(.system(size: 52))
                        .accessibilityHidden(true)
                    Text(title)
                        .font(Theme.heading(.largeTitle))
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: Theme.Space.m) { content }
            }
            .padding(Theme.Space.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A rounded input with a leading icon, matching the Chef AI prompt.
struct AuthField<Content: View>: View {
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            content
        }
        .padding(.horizontal, Theme.Space.l)
        .frame(minHeight: 52)
        .background(Color(.secondarySystemGroupedBackground), in: .capsule)
    }
}

struct AuthButtonLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.body.weight(.semibold))
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 52)
    }
}

/// A raised capsule for the secondary sign-in choices.
struct AuthButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressableStyle().makeBody(configuration: configuration)
            .foregroundStyle(.primary)
            .background(Color(.secondarySystemGroupedBackground), in: .capsule)
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

/// Tilted columns of real recipe photos that fade into the page.
private struct PhotoMosaic: View {
    @Environment(RecipeLibrary.self) private var library

    var body: some View {
        let recipes = Array(stride(from: 0, to: library.bundled.count, by: max(library.bundled.count / 9, 1))
            .map { library.bundled[$0] }
            .prefix(9))
        HStack(alignment: .top, spacing: Theme.Space.m) {
            ForEach(0..<3, id: \.self) { column in
                VStack(spacing: Theme.Space.m) {
                    ForEach(Array(recipes.enumerated()).filter { $0.offset % 3 == column }, id: \.element.id) { _, recipe in
                        Color.clear
                            .frame(width: 128, height: 156)
                            .overlay { RecipePhoto(recipe: recipe, emojiSize: 44) }
                            .clipShape(.rect(cornerRadius: Theme.Radius.photo))
                    }
                }
                .offset(y: column == 1 ? -40 : 10)
            }
        }
        .rotationEffect(.degrees(-8))
        .frame(height: 380)
        .frame(maxWidth: .infinity)
        .clipped()
        .mask(LinearGradient(stops: [.init(color: .black, location: 0.55), .init(color: .clear, location: 1)],
                             startPoint: .top, endPoint: .bottom))
        .accessibilityHidden(true)
    }
}
