import Foundation

/// Finds a cooking time in a recipe step ("simmer 15 minutes", "bake 55 to 65 minutes")
/// so cooking mode can offer a one-tap timer.
enum StepTimer {
    struct Match: Equatable, Sendable {
        /// Seconds to count down. For ranges ("2 to 3 minutes") this is the shorter time,
        /// so you check early rather than overcook.
        let seconds: Int
        /// The words the time came from, e.g. "2 to 3 minutes".
        let label: String
    }

    static func find(in step: String) -> Match? {
        // "15 minutes", "2 to 3 min", "30 seconds", "1 hour"
        let pattern = #/(?i)(\d+)(?:\s*(?:to|-|–)\s*(\d+))?\s*(hours?|hrs?|minutes?|mins?|seconds?|secs?)\b/#
        guard let match = step.firstMatch(of: pattern), let low = Int(match.1) else { return nil }
        let unit = match.3.lowercased()
        let multiplier = unit.hasPrefix("h") ? 3600 : unit.hasPrefix("s") ? 1 : 60
        let seconds = low * multiplier
        guard seconds > 0 else { return nil }
        return Match(seconds: seconds, label: String(match.0))
    }
}
