import Testing
@testable import PlatePlan

struct StepTimerTests {
    @Test func findsMinutes() {
        #expect(StepTimer.find(in: "Simmer 15 minutes, stirring now and then.") == .init(seconds: 900, label: "15 minutes"))
    }

    @Test func usesTheShortEndOfARange() {
        // Check early rather than overcook.
        #expect(StepTimer.find(in: "Bake 55 to 65 minutes, until golden.")?.seconds == 55 * 60)
        #expect(StepTimer.find(in: "Cook 2-3 min per side.")?.seconds == 120)
    }

    @Test func findsSecondsAndHours() {
        #expect(StepTimer.find(in: "Add the garlic and cook 30 seconds.")?.seconds == 30)
        #expect(StepTimer.find(in: "Refrigerate at least 1 hour.")?.seconds == 3600)
    }

    @Test func ignoresStepsWithoutTimes() {
        #expect(StepTimer.find(in: "Heat the oven to 425°F.") == nil)
        #expect(StepTimer.find(in: "Add 2 cups of milk.") == nil)
    }

    @Test func everyBundledTimedStepParses() {
        let steps = ["Bake 20 to 22 minutes, until the centers are set.", "Microwave them 8 to 10 minutes instead, turning halfway."]
        #expect(steps.compactMap(StepTimer.find).map(\.seconds) == [1200, 480])
    }
}
