import SwiftUI

/// The user checks the AI's ingredient list (or types their own) before we look for recipes.
/// This review step is what keeps results accurate: wrong items are one tap away from removal.
struct IngredientReviewView: View {
    struct Item: Identifiable, Hashable {
        let id = UUID()
        var name: String
        var confidence: IngredientScanner.DetectedIngredient.Confidence?
        var isSelected: Bool
    }

    let message: String?
    @State private var items: [Item]
    @State private var newItem = ""
    @FocusState private var addFieldFocused: Bool

    init(detected: [IngredientScanner.DetectedIngredient], message: String?) {
        self.message = message
        // Low-confidence guesses start unchecked, so they're only used if you confirm them.
        _items = State(initialValue: detected.map {
            Item(name: $0.name, confidence: $0.confidence, isSelected: $0.confidence != .low)
        })
    }

    private var selected: [String] { items.filter(\.isSelected).map(\.name) }

    var body: some View {
        List {
            if let message, !message.isEmpty {
                Section {
                    Label(message, systemImage: "sparkles")
                }
            }

            Section {
                ForEach($items) { $item in
                    Button {
                        item.isSelected.toggle()
                    } label: {
                        HStack {
                            Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                            Text(item.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if let confidence = item.confidence, confidence != .high {
                                Text(confidence == .medium ? "Probably" : "Not sure")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.fill.tertiary, in: .capsule)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { items.remove(atOffsets: $0) }

                HStack {
                    TextField("Add an ingredient", text: $newItem)
                        .focused($addFieldFocused)
                        .submitLabel(.done)
                        .onSubmit(addItem)
                    Button("Add", action: addItem)
                        .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Your ingredients")
            } footer: {
                Text(items.isEmpty
                     ? "Add what you have, like \"chicken, rice, broccoli\". Separate several with commas."
                     : "Tap to include or skip an item. Salt, oil, flour and other pantry staples are assumed.")
            }
        }
        .navigationTitle("Check ingredients")
        .safeAreaInset(edge: .bottom) {
            NavigationLink(value: ChefRoute.matches(selected)) {
                Text(selected.isEmpty ? "Pick at least one ingredient" : "Find recipes with \(selected.count) item\(selected.count == 1 ? "" : "s")")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selected.isEmpty)
            .padding()
            .background(.bar)
        }
        .onAppear { if items.isEmpty { addFieldFocused = true } }
    }

    private func addItem() {
        let names = newItem
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        for name in names where !items.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            items.append(Item(name: name.prefix(1).uppercased() + name.dropFirst(), confidence: nil, isSelected: true))
        }
        newItem = ""
    }
}
