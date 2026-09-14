import Foundation
import FirebaseAuth

@MainActor
final class RewardsViewModel: ObservableObject {
    @Published var rewards: [Reward] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            rewards = try await FirestoreService.shared.fetchRewards()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func redeem(_ reward: Reward) async {
        guard let email = Auth.auth().currentUser?.email else { return }
        do {
            try await FirestoreService.shared.redeemReward(email: email, reward: reward)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
