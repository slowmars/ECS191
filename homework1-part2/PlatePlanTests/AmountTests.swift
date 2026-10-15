import Testing
@testable import PlatePlan

struct AmountTests {
    @Test func formatsKitchenFractions() {
        #expect(Units.format(1.5) == "1½")
        #expect(Units.format(0.33) == "⅓")
        #expect(Units.format(0.625) == "⅝")
        #expect(Units.format(2) == "2")
        #expect(Units.format(0.99) == "1")
    }

    @Test func pluralizesUnits() {
        #expect(Amount(value: 2, unit: "cup").formatted == "2 cups")
        #expect(Amount(value: 1, unit: "cup").formatted == "1 cup")
        #expect(Amount(value: 3, unit: "tbsp").formatted == "3 tbsp")
        #expect(Amount(value: 2, unit: "pinch").formatted == "2 pinches")
        #expect(Amount(value: 4, unit: "").formatted == "4")
    }

    @Test func addsSameUnits() {
        #expect(Amount.total([.init(value: 0.5, unit: "cup"), .init(value: 1, unit: "cup")]) == "1½ cups")
    }

    @Test func convertsMixedVolumes() {
        // 1 cup + 4 tbsp of butter = 1¼ cups
        #expect(Amount.total([.init(value: 1, unit: "cup"), .init(value: 4, unit: "tbsp")]) == "1¼ cups")
        // 2 tbsp + 1 tsp = 7 tsp, shown in the bigger unit
        #expect(Amount.total([.init(value: 2, unit: "tbsp"), .init(value: 1, unit: "tsp")]) == "2⅓ tbsp")
        // 1 cup + 3 tbsp doesn't make a tidy fraction
        #expect(Amount.total([.init(value: 1, unit: "cup"), .init(value: 3, unit: "tbsp")]) == "1 cup + 3 tbsp")
    }

    @Test func convertsMixedWeights() {
        #expect(Amount.total([.init(value: 1, unit: "lb"), .init(value: 8, unit: "oz")]) == "1½ lb")
        #expect(Amount.total([.init(value: 6, unit: "oz"), .init(value: 8, unit: "oz")]) == "14 oz")
    }

    @Test func roundsCountsUpForShopping() {
        // You can't buy 1.5 onions.
        #expect(Amount.total([.init(value: 1, unit: ""), .init(value: 0.5, unit: "")]) == "2")
        #expect(Amount.total([.init(value: 0.5, unit: "carton")]) == "1 carton")
    }

    @Test func keepsUnconvertibleUnitsApart() {
        #expect(Amount.total([.init(value: 1, unit: "can"), .init(value: 2, unit: "")]) == "1 can + 2")
    }
}
