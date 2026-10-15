import SwiftUI

/// Create an account or sign in with an email and password.
struct EmailSignInView: View {
    @Environment(AccountStore.self) private var accounts
    @State private var creating = true
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var error: String?
    @FocusState private var focus: Field?

    private enum Field { case name, email, password }

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && (!creating || !name.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        AuthScreen(emoji: creating ? "🍳" : "👋",
                   title: creating ? "Create your account" : "Welcome back",
                   subtitle: creating ? "Save your plan, recipes and food preferences."
                                      : "Sign in to pick up where you left off.") {
            Picker("Account", selection: $creating.animation(.snappy)) {
                Text("New account").tag(true)
                Text("Sign in").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, Theme.Space.s)

            if creating {
                AuthField(systemImage: "person.fill") {
                    TextField("Your name", text: $name)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .focused($focus, equals: .name)
                        .onSubmit { focus = .email }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            AuthField(systemImage: "envelope.fill") {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focus, equals: .email)
                    .onSubmit { focus = .password }
            }
            AuthField(systemImage: "lock.fill") {
                Group {
                    if showPassword {
                        TextField("Password", text: $password)
                    } else {
                        SecureField("Password", text: $password)
                    }
                }
                .textContentType(creating ? .newPassword : .password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($focus, equals: .password)
                .onSubmit(submit)
                Button(showPassword ? "Hide password" : "Show password",
                       systemImage: showPassword ? "eye.slash" : "eye") { showPassword.toggle() }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .frame(width: Theme.minTap, height: Theme.minTap)
            }
            if creating {
                Text("At least 8 characters.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Space.l)
            }

            if let error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: submit) {
                Text(creating ? "Create account" : "Sign in").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSubmit)
            .padding(.top, Theme.Space.s)
        }
        .onChange(of: creating) { error = nil }
        .sensoryFeedback(.error, trigger: error) { _, new in new != nil }
        .onAppear { focus = .name }
    }

    private func submit() {
        guard canSubmit else { return }
        Keyboard.hide {
            do {
                if creating {
                    try accounts.createAccount(name: name.trimmingCharacters(in: .whitespaces), email: email, password: password)
                } else {
                    try accounts.signIn(email: email, password: password)
                }
            } catch let failure {
                withAnimation { error = failure.localizedDescription }
                focus = failure as? AccountStore.AuthError == .invalidEmail ? .email : .password
            }
        }
    }
}

/// Sign in with a phone number and a one-time code.
struct PhoneSignInView: View {
    @Environment(AccountStore.self) private var accounts
    @Binding var path: [AuthRoute]
    @State private var phone = ""
    @State private var code = ""
    /// The verified-format number once a code has been "sent".
    @State private var sentTo: String?
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if let sentTo {
                AuthScreen(emoji: "💬", title: "Enter your code",
                           subtitle: "We sent a 6-digit code to \(Self.display(sentTo)).") {
                    AuthField(systemImage: "number") {
                        TextField("6-digit code", text: $code)
                            .textContentType(.oneTimeCode)
                            .keyboardType(.numberPad)
                            .font(.title3.monospacedDigit())
                            .focused($focused)
                            .onChange(of: code) { _, new in
                                // Digits only, at most 6. Nothing happens until they tap Verify.
                                code = String(new.filter(\.isNumber).prefix(6))
                            }
                    }
                    Text("Demo mode: texts aren't sent yet, so any 6 digits will work.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Theme.Space.l)
                    Button {
                        verify(sentTo)
                    } label: {
                        Text("Verify").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(code.count != 6)
                    Button("Use a different number") {
                        withAnimation(.snappy) { self.sentTo = nil; code = "" }
                    }
                    .font(.subheadline.weight(.semibold))
                }
            } else {
                AuthScreen(emoji: "📱", title: "What's your number?",
                           subtitle: "We'll text you a code to sign in. No password needed.") {
                    AuthField(systemImage: "phone.fill") {
                        Text("+1").foregroundStyle(.secondary)
                        TextField("(555) 123-4567", text: $phone)
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                            .focused($focused)
                    }
                    if let error {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button(action: sendCode) {
                        Text("Send code").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(phone.filter(\.isNumber).count < 10)
                }
            }
        }
        .onAppear { focused = true }
    }

    private func sendCode() {
        do {
            let number = try AccountStore.phoneNumber(phone)
            error = nil
            withAnimation(.snappy) { sentTo = number }
            focused = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func verify(_ number: String) {
        guard code.count == 6 else { return }
        let id = "phone:" + number
        Keyboard.hide {
            if let existing = accounts.existing(id) {
                accounts.signIn(id: id, method: .phone, name: existing.name, contact: number)
            } else {
                path.append(.name(NewAccount(id: id, method: .phone, contact: number)))
            }
        }
    }

    /// "+15305551234" → "(530) 555-1234"
    static func display(_ number: String) -> String {
        let digits = Array(number.filter(\.isNumber).suffix(10))
        guard digits.count == 10 else { return number }
        return "(\(String(digits[0..<3]))) \(String(digits[3..<6]))-\(String(digits[6..<10]))"
    }
}
