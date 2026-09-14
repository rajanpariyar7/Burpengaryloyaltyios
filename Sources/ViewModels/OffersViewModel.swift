import Foundation

@MainActor
final class OffersViewModel: ObservableObject {
    @Published var offers: [Offer] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            offers = try await FirestoreService.shared.fetchOffers()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
