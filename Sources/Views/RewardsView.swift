import SwiftUI
import FirebaseFirestore

struct RewardsView: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @State private var rewards: [Reward] = []
    private let db = Firestore.firestore()

    var body: some View {
        NavigationView {
            List(rewards) { reward in
                VStack(alignment: .leading, spacing: 4) {
                    Text(reward.title).font(.headline)
                    if !reward.description.isEmpty {
                        Text(reward.description)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Text(reward.costInPoints > 0 ? "\(reward.costInPoints) points" : "\(reward.costInStamps) stamps")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Rewards")
            .onAppear(perform: fetchRewards)
        }
    }

    private func fetchRewards() {
        db.collection("rewards").addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error fetching rewards: \(error)")
                return
            }
            self.rewards = snapshot?.documents.compactMap { try? $0.data(as: Reward.self) } ?? []
        }
    }
}
