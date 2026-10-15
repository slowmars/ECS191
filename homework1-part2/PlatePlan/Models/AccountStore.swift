import AuthenticationServices
import CryptoKit
import Foundation
import Observation

/// A PlatePlan account: who you are and what you eat.
struct Account: Codable, Hashable, Identifiable, Sendable {
    enum Method: String, Codable, Sendable {
        case apple, google, email, phone

        var label: String {
            switch self {
            case .apple: "Apple"
            case .google: "Google"
            case .email: "Email"
            case .phone: "Phone"
            }
        }
    }

    /// "email:me@example.com", "phone:+15305551234", "apple:<Apple user ID>"
    let id: String
    let method: Method
    var name: String
    /// Email address or phone number, if known.
    var contact: String
    /// The diet filter on the Recipes tab; nil shows every recipe.
    var dietFilter: Diet?
    var allergies: Set<Allergy> = []

    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "🙂" : String(letters).uppercased()
    }

    /// One line for Chef AI's prompts, or "" when there's nothing to follow.
    var chefNote: String {
        var parts: [String] = []
        if let diet = dietFilter, diet != .nonVegetarian {
            parts.append("I'm \(diet.rawValue.lowercased()): \(diet.detail.lowercased()).")
        }
        if !allergies.isEmpty {
            parts.append("I'm allergic to \(allergies.map { $0.rawValue.lowercased() }.sorted().joined(separator: ", ")); never use them.")
        }
        guard !parts.isEmpty else { return "" }
        return (parts + ["Follow this unless I clearly ask for something else, and mention any swaps in \"message\"."])
            .joined(separator: " ")
    }
}

/// Signs people in and remembers their profile.
///
/// For now accounts live on this phone only (no server): an email password is stored as a salted
/// hash, and phone codes aren't really sent. Sign in with Apple is real once the app's developer
/// account has the capability turned on. Swapping in Firebase or another backend later only changes
/// this class; the screens stay the same.
@MainActor
@Observable
final class AccountStore {
    enum AuthError: LocalizedError {
        case accountExists, noAccount, wrongPassword, weakPassword, invalidEmail, invalidPhone

        var errorDescription: String? {
            switch self {
            case .accountExists: "There's already an account with that email. Sign in instead."
            case .noAccount: "We couldn't find an account with that email."
            case .wrongPassword: "That password isn't right."
            case .weakPassword: "Use at least 8 characters."
            case .invalidEmail: "That doesn't look like an email address."
            case .invalidPhone: "Enter a 10-digit phone number."
            }
        }
    }

    private(set) var current: Account? {
        didSet { persist() }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var accounts: [String: Account]
    @ObservationIgnored private var passwords: [String: String]

    private static let accountsKey = "accounts", passwordsKey = "passwordHashes", currentKey = "currentAccount"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        accounts = (defaults.data(forKey: Self.accountsKey))
            .flatMap { try? JSONDecoder().decode([String: Account].self, from: $0) } ?? [:]
        passwords = defaults.dictionary(forKey: Self.passwordsKey) as? [String: String] ?? [:]
        current = defaults.string(forKey: Self.currentKey).flatMap { accounts[$0] }
        #if DEBUG
        // `-skipLogin YES` signs in a sample user (used for simulator screenshots).
        if current == nil, defaults.bool(forKey: "skipLogin") {
            current = Account(id: "debug", method: .email, name: "Alex Rivera", contact: "alex@example.com")
        }
        #endif
    }

    // MARK: Signing in

    /// The account for an email, phone or Apple ID, if this phone has seen it before.
    func existing(_ id: String) -> Account? { accounts[id] }

    func signIn(email: String, password: String) throws {
        let id = try Self.emailID(email)
        guard let account = accounts[id] else { throw AuthError.noAccount }
        guard passwords[id] == Self.hash(password, for: id) else { throw AuthError.wrongPassword }
        current = account
    }

    func createAccount(name: String, email: String, password: String) throws {
        let id = try Self.emailID(email)
        guard accounts[id] == nil else { throw AuthError.accountExists }
        guard password.count >= 8 else { throw AuthError.weakPassword }
        passwords[id] = Self.hash(password, for: id)
        current = Account(id: id, method: .email, name: name, contact: email.trimmingCharacters(in: .whitespaces))
    }

    /// Signs in a returning user, or creates the account once we know their name.
    func signIn(id: String, method: Account.Method, name: String, contact: String) {
        if var account = accounts[id] {
            if account.contact.isEmpty { account.contact = contact }
            current = account
        } else {
            current = Account(id: id, method: method, name: name, contact: contact)
        }
    }

    func signOut() {
        current = nil
    }

    /// Apple asks apps to check that a Sign in with Apple account is still connected: people can
    /// stop using their Apple ID with the app in iOS Settings, and then they should be signed out.
    /// Checked at launch and whenever Apple reports a change.
    func watchAppleSignIn() async {
        await checkAppleCredential()
        for await _ in NotificationCenter.default.notifications(named: ASAuthorizationAppleIDProvider.credentialRevokedNotification) {
            await checkAppleCredential()
        }
    }

    private func checkAppleCredential() async {
        guard let account = current, account.method == .apple else { return }
        let userID = String(account.id.dropFirst("apple:".count))
        let state = try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: userID)
        if state == .revoked || state == .notFound, current?.id == account.id { signOut() }
    }

    /// Removes the account and everything stored with it (App Store rule 5.1.1(v)).
    func deleteAccount() {
        guard let id = current?.id else { return }
        accounts[id] = nil
        passwords[id] = nil
        current = nil
    }

    /// Whether to show a recipe: it passes the diet filter (everything does when none is chosen)
    /// and has none of the person's allergens.
    func shows(_ recipe: Recipe) -> Bool {
        guard let account = current else { return true }
        return (account.dietFilter?.allows(recipe) ?? true) && Allergy.isSafe(recipe, avoiding: account.allergies)
    }

    func update(_ change: (inout Account) -> Void) {
        guard var account = current else { return }
        change(&account)
        current = account
    }

    // MARK: Helpers

    /// A file-safe name for an account's own storage folder and keys.
    nonisolated static func storageID(_ accountID: String) -> String {
        SHA256.hash(data: Data(accountID.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    static func emailID(_ email: String) throws -> String {
        let email = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard email.wholeMatch(of: #/[^@\s]+@[^@\s]+\.[a-z]{2,}/#) != nil else { throw AuthError.invalidEmail }
        return "email:" + email
    }

    /// Digits only, with the US country code: "(530) 555-1234" → "+15305551234".
    static func phoneNumber(_ text: String) throws -> String {
        var digits = text.filter(\.isNumber)
        if digits.count == 11, digits.hasPrefix("1") { digits.removeFirst() }
        guard digits.count == 10 else { throw AuthError.invalidPhone }
        return "+1" + digits
    }

    private static func hash(_ password: String, for id: String) -> String {
        SHA256.hash(data: Data("platePlan|\(id)|\(password)".utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func persist() {
        if let current, current.id != "debug" { accounts[current.id] = current }
        defaults.set(try? JSONEncoder().encode(accounts), forKey: Self.accountsKey)
        defaults.set(passwords, forKey: Self.passwordsKey)
        defaults.set(current?.id, forKey: Self.currentKey)
    }
}
