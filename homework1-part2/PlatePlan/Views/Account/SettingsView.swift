import SwiftUI
import UIKit

/// Light, dark, or follow the phone.
enum Appearance: String, CaseIterable, Identifiable {
    case system = "System", light = "Light", dark = "Dark"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    var detail: String {
        switch self {
        case .system: "Match your iPhone's setting"
        case .light: "Always light"
        case .dark: "Always dark"
        }
    }

    /// Sets the style on every window, so screens that are already open (like this sheet) switch too.
    @MainActor
    func apply() {
        let style: UIUserInterfaceStyle = switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows { window.overrideUserInterfaceStyle = style }
        }
    }
}

/// Profile, food preferences, cooking options and the account itself, in one place.
/// Rows use small colored icon tiles, like the iOS Settings app.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AccountStore.self) private var accounts
    /// Runs after this sheet has closed. Signing out swaps the whole app for the sign-in screen,
    /// so Settings closes first; otherwise iOS holds the sheet open until the swap finishes.
    @Binding var afterClose: (() -> Void)?
    @Environment(StepReader.self) private var reader
    @Environment(MealPlan.self) private var plan
    @Environment(RecipeLibrary.self) private var library
    @AppStorage(StepReader.speedKey) private var speechSpeed = StepReader.Speed.normal
    @AppStorage(StepReader.voiceKey) private var voiceID = ""
    @AppStorage("appearance") private var appearance = Appearance.system
    /// The name being edited. Saved on Done (or when Settings closes), not on every keystroke,
    /// which would redraw the whole app while typing.
    @State private var nameDraft = ""
    @FocusState private var editingName: Bool
    @State private var confirmingSignOut = false
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            List {
                if let account = accounts.current {
                    profile(account)
                    food(account)
                }
                cooking
                appearanceSection
                Section("About") {
                    NavigationLink {
                        PhotoCreditsView()
                    } label: {
                        SettingsRow("Photo credits", systemImage: "photo.on.rectangle", color: .teal)
                    }
                    LabeledContent {
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    } label: {
                        SettingsRow("Version", systemImage: "info", color: .gray)
                    }
                }
                accountActions
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { dismiss() }
                    .fontWeight(.semibold)
            }
        }
        .onDisappear {
            saveName()
            reader.finish()
        }
    }

    // MARK: Sections

    private func profile(_ account: Account) -> some View {
        Section {
            HStack(spacing: Theme.Space.l) {
                Text(account.initials)
                    .font(Theme.heading(.title2))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(
                        LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: .circle
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name.isEmpty ? "Your profile" : account.name)
                        .font(Theme.heading(.title3))
                    Text(account.contact.isEmpty ? "Signed in with \(account.method.label)"
                                                 : "\(account.contact) · \(account.method.label)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, Theme.Space.xs)

            LabeledContent {
                TextField("Your name", text: $nameDraft)
                    .multilineTextAlignment(.trailing)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($editingName)
                    .onSubmit(saveName)
                    .onAppear { nameDraft = account.name }
                    .onChange(of: editingName) { _, editing in if !editing { saveName() } }
            } label: {
                SettingsRow("Name", systemImage: "person.fill", color: .blue)
            }
        }
    }

    private func food(_ account: Account) -> some View {
        Section {
            NavigationLink {
                AllergyPicker(allergies: binding(\.allergies, default: []))
            } label: {
                LabeledContent {
                    Text(account.allergies.isEmpty ? "None" : "\(account.allergies.count)")
                } label: {
                    SettingsRow("Allergies", systemImage: "allergens", color: .orange)
                }
            }
        } header: {
            Text("Food preferences")
        } footer: {
            Text("Recipes with your allergens are hidden everywhere, and Chef AI leaves them out. Pick a diet with the filter on the Recipes tab.")
        }
    }

    private var cooking: some View {
        Section {
            NavigationLink {
                VoicePicker(voiceID: $voiceID)
            } label: {
                LabeledContent {
                    Text(SpeechVoice.installed.first { $0.id == SpeechVoice.preferred(voiceID) }?.name ?? "Default")
                } label: {
                    SettingsRow("Voice", systemImage: "waveform", color: .purple)
                }
            }
            Picker(selection: $speechSpeed) {
                ForEach(StepReader.Speed.allCases) { Text($0.rawValue).tag($0) }
            } label: {
                SettingsRow("Speaking speed", systemImage: "gauge.with.dots.needle.50percent", color: .indigo)
            }
        } header: {
            Text("Cooking")
        } footer: {
            Text("Nothing plays until you tap Listen on a step, or the speaker button to hear every step as you go. Cooking timers ring like the Clock app, even when your phone is locked.")
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            ForEach(Appearance.allCases) { option in
                Button {
                    appearance = option
                } label: {
                    HStack {
                        SettingsRow(option.rawValue, systemImage: option.systemImage, color: .blue)
                        Spacer()
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(.tint)
                            .opacity(appearance == option ? 1 : 0)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(appearance == option ? .isSelected : [])
                .accessibilityHint(option.detail)
            }
        }
        .sensoryFeedback(.selection, trigger: appearance)
    }

    private var accountActions: some View {
        Section {
            Button("Sign out") { confirmingSignOut = true }
                .frame(maxWidth: .infinity)
                .confirmationDialog("Sign out of Cookd?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
                    Button("Sign out", role: .destructive) { close { accounts.signOut() } }
                } message: {
                    Text("Your plan and saved recipes will be here when you sign back in.")
                }
            Button("Delete account", role: .destructive) { confirmingDelete = true }
                .frame(maxWidth: .infinity)
                .confirmationDialog("Delete your account?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                    Button("Delete account", role: .destructive) {
                        close {
                            plan.erase()
                            library.eraseSaved()
                            accounts.deleteAccount()
                        }
                    }
                } message: {
                    Text("This removes your profile, preferences, meal plan and saved recipes. It can't be undone.")
                }
        }
    }

    private func saveName() {
        let name = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != accounts.current?.name else { return }
        accounts.update { $0.name = name }
    }

    private func close(then action: @escaping () -> Void) {
        afterClose = action
        dismiss()
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<Account, Value>, default fallback: Value) -> Binding<Value> {
        Binding(
            get: { accounts.current?[keyPath: keyPath] ?? fallback },
            set: { value in accounts.update { $0[keyPath: keyPath] = value } }
        )
    }
}

/// A settings label with a white symbol on a small colored tile.
private struct SettingsRow: View {
    let title: String
    let systemImage: String
    let color: Color

    init(_ title: String, systemImage: String, color: Color) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color.gradient, in: .rect(cornerRadius: 7))
        }
    }
}

// MARK: - Pickers

private struct AllergyPicker: View {
    @Binding var allergies: Set<Allergy>

    var body: some View {
        List {
            Section {
                ForEach(Allergy.allCases) { allergy in
                    Toggle(allergy.rawValue, isOn: Binding(
                        get: { allergies.contains(allergy) },
                        set: { if $0 { allergies.insert(allergy) } else { allergies.remove(allergy) } }
                    ))
                }
            } footer: {
                Text("Recipes that contain these are hidden, and Chef AI won't use them. We check ingredient names, not packaging, so always read labels for traces and cross-contact.")
            }
        }
        .navigationTitle("Allergies")
    }
}

/// Every good voice on the phone, best first. Tap one to choose it and hear a sample.
private struct VoicePicker: View {
    @Environment(StepReader.self) private var reader
    @Binding var voiceID: String

    private var groups: [(SpeechVoice.Quality, [SpeechVoice])] {
        let voices = SpeechVoice.installed
        return [SpeechVoice.Quality.premium, .enhanced, .standard].compactMap { quality in
            let matching = voices.filter { $0.quality == quality }
            return matching.isEmpty ? nil : (quality, matching)
        }
    }

    var body: some View {
        let chosen = SpeechVoice.preferred(voiceID)
        List {
            ForEach(groups, id: \.0) { quality, voices in
                Section(quality.label) {
                    ForEach(voices) { voice in
                        Button {
                            voiceID = voice.id
                            reader.read("Hi! I'll read your recipe steps out loud while you cook.", voiceID: voice.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(voice.name)
                                    Text(voice.region).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.tint)
                                    .opacity(voice.id == chosen ? 1 : 0)
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(voice.id == chosen ? .isSelected : [])
                    }
                }
            }
            Section {
                Button("Get more voices", systemImage: "arrow.down.circle") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            } footer: {
                Text("Siri's own voice is kept for Siri and isn't available to apps. Premium voices like Ava, Zoe and Evan sound the most natural. Download them in iOS Settings › Accessibility › Spoken Content › Voices › English, then come back here.")
            }
        }
        .navigationTitle("Voice")
        .onDisappear { reader.stop() }
    }
}
