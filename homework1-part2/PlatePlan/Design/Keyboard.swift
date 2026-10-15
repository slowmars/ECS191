import UIKit

/// Hiding the keyboard before moving on.
///
/// If a button swaps the screen while the keyboard is still up (signing in, sending a recipe request),
/// iOS keeps the keyboard on screen until the new screen has finished loading, so it seems to hang
/// for a second. Hiding it first, then moving on as it slides away, feels instant.
@MainActor
enum Keyboard {
    static func hide() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// Hides the keyboard, then runs `action` once it has started sliding away.
    static func hide(then action: @escaping @MainActor () -> Void) {
        hide()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            action()
        }
    }
}
