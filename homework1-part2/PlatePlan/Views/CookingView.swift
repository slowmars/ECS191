import SwiftUI

/// Cooking mode: pick servings and gather ingredients, then swipe sideways through one big step
/// at a time. Ends on a small celebration that marks the meal as cooked (peak-end rule).
/// The screen stays awake the whole time, and speaker mode reads each step aloud as you reach it.
struct CookingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MealPlan.self) private var plan
    let recipe: Recipe
    @State private var servings: Int
    /// -1 is the ingredients page; 0..<steps are steps; steps.count is the finish page.
    @State private var page = -1
    @State private var gathered: Set<Int> = []
    @Environment(StepReader.self) private var reader
    /// Sound on: each page is read aloud as you reach it. Off (muted) means nothing plays.
    @State private var speakerOn = false
    @State private var pendingRead: Task<Void, Never>?

    init(recipe: Recipe, servings: Int) {
        self.recipe = recipe
        _servings = State(initialValue: servings)
        #if DEBUG
        // `-cookPage N` opens a specific step (used for simulator screenshots).
        if let page = UserDefaults.standard.object(forKey: "cookPage") as? Int { _page = State(initialValue: page) }
        else if let text = UserDefaults.standard.string(forKey: "cookPage"), let page = Int(text) { _page = State(initialValue: page) }
        #endif
    }

    private var lastStep: Int { recipe.steps.count - 1 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if page >= 0 && page <= lastStep { stepProgress }
                RunningTimersStrip(recipe: recipe, currentStep: page)

                TabView(selection: $page) {
                    prep.tag(-1)
                    ForEach(recipe.steps.indices, id: \.self) { index in
                        StepPage(recipe: recipe, index: index, servingsChanged: servings != recipe.servings)
                            .tag(index)
                    }
                    FinishPage(recipe: recipe, inPlan: plan.contains(recipe)) { dismiss() }
                        .tag(recipe.steps.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.snappy, value: page)

                if page <= lastStep { controls }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(recipe.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(speakerOn ? "Mute" : "Read steps aloud",
                           systemImage: speakerOn ? "speaker.wave.2.fill" : "speaker.slash") {
                        if speakerOn { mute() } else { listen() }
                    }
                    .symbolEffect(.variableColor.iterative, isActive: reader.isSpeaking)
                    .contentTransition(.symbolEffect(.replace))
                }
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            pendingRead?.cancel()
            reader.finish()
        }
        .onChange(of: page) { _, page in
            if page == recipe.steps.count, plan.contains(recipe) { plan.setCooked(true, for: recipe) }
            pendingRead?.cancel()
            if reader.isSpeaking { reader.stop() }
            if speakerOn {
                // Start once the page has slid in, so swiping stays smooth.
                pendingRead = Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    if !Task.isCancelled { readAloud() }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: page)
    }

    /// Turns the sound on and reads this page; later pages are read as you reach them.
    private func listen() {
        speakerOn = true
        readAloud()
    }

    private func mute() {
        speakerOn = false
        pendingRead?.cancel()
        reader.stop()
    }

    /// Reads the current page: the ingredient list, a step, or the finish.
    private func readAloud() {
        let text: String
        switch page {
        case -1:
            let factor = Double(servings) / Double(max(recipe.servings, 1))
            let items = recipe.ingredients.map { ingredient in
                [ingredient.amount(scaledBy: factor)?.formatted, ingredient.name.lowercased()]
                    .compactMap { $0 }.joined(separator: " ")
            }
            text = "\(recipe.name), for \(servings). You'll need: \(items.joined(separator: ", ")). Tap start cooking when you're ready."
        case recipe.steps.count:
            text = "Enjoy your meal!"
        default:
            text = "Step \(page + 1). \(recipe.steps[page])"
        }
        reader.read(text)
    }

    /// One segment per step, so you always know how far along you are.
    private var stepProgress: some View {
        VStack(spacing: Theme.Space.s) {
            HStack(spacing: 4) {
                ForEach(recipe.steps.indices, id: \.self) { index in
                    Capsule()
                        .fill(index <= page ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.tertiary))
                        .frame(height: 4)
                }
            }
            HStack {
                Text("Step \(page + 1) of \(recipe.steps.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Step \(page + 1) of \(recipe.steps.count)")
                Spacer()
                // Hear just this step, whether or not speaker mode is on.
                Button {
                    if reader.isSpeaking { reader.stop() } else { listen() }
                } label: {
                    Label(reader.isSpeaking ? "Stop" : "Listen",
                          systemImage: reader.isSpeaking ? "stop.fill" : "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.borderless)
            }
            .frame(minHeight: 22)
        }
        .padding(.horizontal, Theme.Space.xl)
        .padding(.top, Theme.Space.s)
    }

    /// Buttons as well as swiping, since not everyone discovers swipe gestures.
    private var controls: some View {
        HStack(spacing: Theme.Space.m) {
            if page >= 0 {
                Button {
                    page -= 1
                } label: {
                    Label(page == 0 ? "Ingredients" : "Back", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            Button {
                page += 1
            } label: {
                Label(page == -1 ? "Start cooking" : page == lastStep ? "Finish" : "Next step",
                      systemImage: page == -1 ? "flame.fill" : page == lastStep ? "checkmark" : "chevron.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .controlSize(.large)
        .padding(.horizontal, Theme.Space.l)
        .padding(.vertical, Theme.Space.m)
        .background(.bar)
    }

    /// Choose servings and check off ingredients before starting.
    private var prep: some View {
        let factor = Double(servings) / Double(max(recipe.servings, 1))
        return List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cooking for").font(.headline)
                        Text("Amounts below adjust automatically").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    ServingsControl(servings: $servings)
                }
            }

            Section {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                    let isGathered = gathered.contains(index)
                    Button {
                        withAnimation(.snappy) {
                            if isGathered { gathered.remove(index) } else { gathered.insert(index) }
                        }
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.m) {
                            Image(systemName: isGathered ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(isGathered ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                            Text(ingredient.amount(scaledBy: factor)?.formatted ?? "")
                                .fontWeight(.semibold)
                                .frame(width: 84, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ingredient.name)
                                if !ingredient.note.isEmpty {
                                    Text(ingredient.note).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .opacity(isGathered ? 0.5 : 1)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: isGathered)
                    .accessibilityAddTraits(isGathered ? .isSelected : [])
                }
            } header: {
                Text("Gather your ingredients · \(gathered.count) of \(recipe.ingredients.count)")
            }
        }
        .scrollContentBackground(.hidden)
    }
}

/// One step, big and readable from across the counter, with a timer when the step mentions a time.
private struct StepPage: View {
    let recipe: Recipe
    let index: Int
    let servingsChanged: Bool

    private var step: String { recipe.steps[index] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                Text(step)
                    .font(Theme.heading(.title, weight: .semibold))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let timer = StepTimer.find(in: step) {
                    StepTimerView(match: timer, recipe: recipe, step: index)
                }

                if servingsChanged && step.contains(where: \.isNumber) {
                    Label("Amounts in this step are for \(recipe.servings) servings. Use your ingredient list.",
                          systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(Theme.Space.xl)
        }
    }
}

/// The end of the meal: a moment of reward, then back to the plan.
private struct FinishPage: View {
    let recipe: Recipe
    let inPlan: Bool
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: Theme.Space.xl) {
            Spacer()
            RecipePhoto(recipe: recipe, emojiSize: 72)
                .frame(width: 180, height: 180)
                .clipShape(.circle)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white, Color.accentColor)
                        .background(Circle().fill(.background).padding(4))
                }
            VStack(spacing: Theme.Space.s) {
                Text("Enjoy your meal!")
                    .font(Theme.heading(.largeTitle))
                Text(inPlan ? "\(recipe.name) is marked as cooked in your plan." : "You cooked \(recipe.name).")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onDone) {
                Text("Done").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(Theme.Space.xl)
    }
}

/// A step's timer. Tapping start sets a real system timer that rings even if the app is closed.
private struct StepTimerView: View {
    @Environment(TimerCenter.self) private var timers
    let match: StepTimer.Match
    let recipe: Recipe
    let step: Int
    @State private var starting = false

    private var key: String { TimerCenter.key(recipeID: recipe.id, step: step) }

    var body: some View {
        Group {
            if let running = timers.timer(for: key) {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let left = max(0, Int(running.fireDate.timeIntervalSince(context.date).rounded(.up)))
                        HStack(alignment: .firstTextBaseline) {
                            Image(systemName: left == 0 ? "bell.and.waves.left.and.right.fill" : "timer")
                                .foregroundStyle(left == 0 ? AnyShapeStyle(.orange) : AnyShapeStyle(.tint))
                            Text(left == 0 ? "Time's up!" : Self.clock(left))
                                .font(.system(size: 48, weight: .semibold, design: .rounded).monospacedDigit())
                                .contentTransition(.numericText(countsDown: true))
                                .foregroundStyle(left == 0 ? AnyShapeStyle(.orange) : AnyShapeStyle(.primary))
                        }
                    }
                    Text(running.usesAlarm
                         ? "Rings like the Clock app, even if you lock your phone or leave the app."
                         : "You'll get a notification when it's done.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Stop timer", systemImage: "stop.fill", role: .destructive) {
                        withAnimation { timers.cancel(running) }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Space.l)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Theme.Radius.card))
            } else {
                Button {
                    starting = true
                    Task {
                        await timers.start(seconds: match.seconds, recipe: recipe, step: step)
                        starting = false
                    }
                } label: {
                    Label(starting ? "Starting…" : "Start \(Self.clock(match.seconds)) timer", systemImage: "timer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(starting)
            }
        }
        .sensoryFeedback(.start, trigger: timers.timer(for: key)?.id)
    }

    /// 905 → "15:05", 3900 → "1:05:00"
    static func clock(_ seconds: Int) -> String {
        let h = seconds / 3600, m = seconds % 3600 / 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

/// Timers running for other steps stay visible while you move on (rice simmering while you cook the chicken).
private struct RunningTimersStrip: View {
    @Environment(TimerCenter.self) private var timers
    let recipe: Recipe
    let currentStep: Int

    var body: some View {
        let others = timers.running.filter {
            $0.key.hasPrefix(recipe.id + "#") && $0.key != TimerCenter.key(recipeID: recipe.id, step: currentStep)
        }
        if !others.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.s) {
                    ForEach(others) { timer in
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let left = max(0, Int(timer.fireDate.timeIntervalSince(context.date).rounded(.up)))
                            Label("\(timer.title.components(separatedBy: " · ").first ?? "") · \(left == 0 ? "done" : StepTimerView.clock(left))",
                                  systemImage: left == 0 ? "bell.fill" : "timer")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .padding(.horizontal, Theme.Space.m)
                                .padding(.vertical, Theme.Space.s)
                                .background(left == 0 ? AnyShapeStyle(.orange.opacity(0.2)) : AnyShapeStyle(.tint.opacity(0.12)), in: .capsule)
                        }
                    }
                }
                .padding(.horizontal, Theme.Space.l)
            }
            .padding(.top, Theme.Space.s)
        }
    }
}
