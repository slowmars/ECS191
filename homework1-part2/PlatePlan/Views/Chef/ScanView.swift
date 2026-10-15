import SwiftUI

/// Sends the photo to the AI, then hands the result to the review screen.
struct ScanView: View {
    @Environment(RecipeLibrary.self) private var library
    let photo: ScanPhoto

    private enum Phase {
        case scanning
        case failed(String)
        case done(IngredientScanner.Result)
    }

    @State private var phase = Phase.scanning

    var body: some View {
        switch phase {
        case .done(let result):
            IngredientReviewView(detected: result.ingredients, message: result.message)
        case .scanning:
            VStack(spacing: 20) {
                preview
                ChefThinkingView(title: "Looking for ingredients…", steps: [
                    "Spotting what's in the photo…",
                    "Reading package labels…",
                    "Matching them to recipes…",
                ])
            }
            .padding()
            .navigationTitle("Scanning")
            .task { await scan() }
        case .failed(let message):
            VStack(spacing: 20) {
                preview
                ContentUnavailableView {
                    Label("Scan didn't work", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try again") {
                        phase = .scanning
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("Scanning")
        }
    }

    private var preview: some View {
        Image(uiImage: photo.image)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 280)
            .clipShape(.rect(cornerRadius: 16))
    }

    private func scan() async {
        do {
            let client = try ClaudeClient.fromBundle()
            // Resizing a full-size camera photo is slow, so keep it off the main thread.
            let image = photo.image
            guard let jpeg = await Task.detached(priority: .userInitiated, operation: { PhotoEncoding.jpegBase64(from: image) }).value else {
                phase = .failed("Couldn't read that photo. Try another one.")
                return
            }
            let result = try await IngredientScanner(client: client)
                .scan(jpegBase64: jpeg, knownIngredients: library.ingredientNames)
            phase = .done(result)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
