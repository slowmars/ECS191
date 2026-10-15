import SwiftUI

@main
struct PlatePlanApp: App {
    @State private var library = RecipeLibrary()
    @State private var plan = MealPlan()
    @State private var router = Router(tab: RootView.initialTab)
    @State private var timers = TimerCenter()
    @State private var accounts = AccountStore()
    @State private var reader = StepReader()
    @AppStorage("appearance") private var appearance = Appearance.system
    /// The account whose plan and saved recipes are loaded. The app waits for this to match
    /// the signed-in account, so nobody ever sees the previous person's data.
    @State private var loadedAccount: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let account = accounts.current {
                    if loadedAccount == account.id {
                        RootView()
                            .id(account.id)
                            .transition(.opacity)
                    }
                } else {
                    LoginView()
                        .transition(.opacity)
                }
            }
            .animation(.smooth, value: accounts.current == nil)
            .task { await accounts.watchAppleSignIn() }
            .onChange(of: accounts.current?.id, initial: true) { _, id in
                guard let id else { return }
                plan.load(account: id)
                library.load(account: id)
                // A different person starts on Recipes, not wherever the last one left off.
                if loadedAccount != nil { router.tab = .recipes }
                loadedAccount = id
            }
            .environment(library)
            .environment(plan)
            .environment(router)
            .environment(timers)
            .environment(accounts)
            .environment(reader)
            // Set on the window, so sheets that are already open (like Settings) switch too.
            .onChange(of: appearance, initial: true) { _, appearance in appearance.apply() }
        }
    }
}
