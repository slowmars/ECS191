import Foundation

/// A quantity in a recipe unit, with the conversion and formatting the shopping list needs.
struct Amount: Equatable, Sendable {
    var value: Double
    var unit: String

    /// "1½ cups", "2 cloves", "3".
    var formatted: String {
        let number = Units.format(value)
        return unit.isEmpty ? number : number + " " + Units.label(unit, for: value)
    }

    /// Adds amounts of the same ingredient together.
    /// Same unit: summed in that unit. Mixed volumes (cup + tbsp) or weights (lb + oz) are converted.
    /// Units that can't be converted (2 cans + 1 jar) stay side by side.
    static func total(_ amounts: [Amount], roundingUpCounts: Bool = true) -> String {
        var order: [String] = []
        var groups: [String: [Amount]] = [:]
        for amount in amounts {
            let key = Units.family(of: amount.unit) ?? amount.unit
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(amount)
        }

        return order.compactMap { key -> String? in
            guard let group = groups[key] else { return nil }
            let units = Set(group.map(\.unit))
            if units.count == 1, let unit = units.first {
                var sum = group.reduce(0) { $0 + $1.value }
                // You can't buy half a can or 1.5 eggs.
                if roundingUpCounts && Units.isCountable(unit) { sum = sum.rounded(.up) }
                return Amount(value: sum, unit: unit).formatted
            }
            let base = group.reduce(0) { $0 + Units.toBase($1) }
            return key == "volume" ? Units.formatVolume(teaspoons: base) : Units.formatWeight(ounces: base)
        }
        .joined(separator: " + ")
    }
}

enum Units {
    static let all = ["", "cup", "tbsp", "tsp", "lb", "oz", "clove", "can", "jar", "slice", "pinch", "head",
                      "bunch", "stalk", "packet", "carton", "pint"]

    private static let teaspoonsPer: [String: Double] = ["pinch": 1.0 / 16, "tsp": 1, "tbsp": 3, "cup": 48]
    private static let ouncesPer: [String: Double] = ["oz": 1, "lb": 16]
    /// Written the same in singular and plural.
    private static let invariant: Set<String> = ["tbsp", "tsp", "lb", "oz"]
    private static let measured: Set<String> = ["cup", "tbsp", "tsp", "lb", "oz", "pinch"]

    static func family(of unit: String) -> String? {
        if teaspoonsPer[unit] != nil { return "volume" }
        if ouncesPer[unit] != nil { return "weight" }
        return nil
    }

    static func isCountable(_ unit: String) -> Bool { !measured.contains(unit) }

    /// Teaspoons for volumes, ounces for weights, the count itself otherwise.
    static func toBase(_ amount: Amount) -> Double {
        amount.value * (teaspoonsPer[amount.unit] ?? ouncesPer[amount.unit] ?? 1)
    }

    /// Formats a base quantity (see `toBase`) in the most readable unit of `unit`'s family.
    static func formatBase(_ base: Double, like unit: String) -> String {
        switch family(of: unit) {
        case "volume": formatVolume(teaspoons: base)
        case "weight": formatWeight(ounces: base)
        default: Amount(value: base, unit: unit).formatted
        }
    }

    static func label(_ unit: String, for value: Double) -> String {
        if invariant.contains(unit) || value <= 1 { return unit }
        return ["pinch", "bunch"].contains(unit) ? unit + "es" : unit + "s"
    }

    static func formatVolume(teaspoons: Double) -> String {
        let cups = teaspoons / 48
        if cups >= 0.25, isTidy(cups) { return Amount(value: cups, unit: "cup").formatted }
        if teaspoons < 12 {
            let tbsp = teaspoons / 3
            return tbsp >= 1 && isTidy(tbsp)
                ? Amount(value: tbsp, unit: "tbsp").formatted
                : Amount(value: teaspoons, unit: "tsp").formatted
        }
        // e.g. 1 cup + 3 tbsp
        let wholeQuarters = (cups * 4).rounded(.down) / 4
        let restTbsp = ((teaspoons - wholeQuarters * 48) / 3 * 2).rounded() / 2
        let cupText = Amount(value: wholeQuarters, unit: "cup").formatted
        return restTbsp > 0 ? cupText + " + " + Amount(value: restTbsp, unit: "tbsp").formatted : cupText
    }

    static func formatWeight(ounces: Double) -> String {
        let pounds = ounces / 16
        if pounds >= 1, isTidy(pounds) { return Amount(value: pounds, unit: "lb").formatted }
        if ounces < 16 { return Amount(value: ounces, unit: "oz").formatted }
        let whole = pounds.rounded(.down)
        return Amount(value: whole, unit: "lb").formatted + " " + Amount(value: ounces - whole * 16, unit: "oz").formatted
    }

    /// Whether a value is a whole number or a kitchen fraction (¼, ⅓, ½...).
    private static func isTidy(_ value: Double) -> Bool {
        let fraction = value - value.rounded(.down)
        return [0, 0.25, 1.0 / 3, 0.5, 2.0 / 3, 0.75, 1].contains { abs($0 - fraction) < 0.02 }
    }

    private static let fractions: [(value: Double, glyph: String)] = [
        (0, ""), (0.125, "⅛"), (0.25, "¼"), (1.0 / 3, "⅓"), (0.375, "⅜"), (0.5, "½"),
        (0.625, "⅝"), (2.0 / 3, "⅔"), (0.75, "¾"), (0.875, "⅞"), (1, ""),
    ]

    /// 1.5 → "1½", 0.33 → "⅓", 2 → "2". Snaps to the nearest kitchen fraction (eighths or thirds).
    static func format(_ value: Double) -> String {
        guard value > 0 else { return "0" }
        var whole = value.rounded(.down)
        let nearest = fractions.min { abs($0.value - (value - whole)) < abs($1.value - (value - whole)) }!
        if nearest.value == 1 { whole += 1 }
        if whole == 0 && nearest.glyph.isEmpty { return "⅛" }  // tiny amounts still show something
        let wholeText = whole == 0 ? "" : String(Int(whole))
        return wholeText + (nearest.value == 1 ? "" : nearest.glyph)
    }
}
