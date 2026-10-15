import AlarmKit

/// Extra info carried by a cooking timer, shared by the app and the Lock Screen widget.
nonisolated struct CookingTimerMetadata: AlarmMetadata {
    var recipeName: String
    var stepNumber: Int

    var title: String { "Step \(stepNumber) · \(recipeName)" }
}
