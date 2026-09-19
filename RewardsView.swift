import SwiftUI

struct RewardsView: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @State private var redeemedIds: Set<String> = []
    @State private var confirmingReward: Reward?
    @State private var isRedeeming = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0xF3/255.0, green: 0xF4/255.0, blue: 0xF1/255.0).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        balanceHeader

                        if viewModel.rewards.isEmpty {
                            Text("No rewards available right now — check back soon!")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .padding(.top, 40)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.rewards) { reward in
                                    rewardCard(reward)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Rewards")
            .navigationBarTitleDisplayMode(.inline)
            .task { await refreshRedeemed() }
            .alert("Redeem Reward?", isPresented: Binding(
                get: { confirmingReward != nil },
                set: { if !$0 { confirmingReward = nil } }
            )) {
                Button("Redeem", role: .none) {
                    if let reward = confirmingReward {
                        redeem(reward)
                    }
                }
                Button("Cancel", role: .cancel) { confirmingReward = nil }
            } message: {
                if let reward = confirmingReward {
                    Text(costDescription(reward) + " will be deducted. This can't be undone.")
                }
            }
        }
    }

    private var balanceHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("YOUR BALANCE").font(.system(size: 11, weight: .bold)).foregroundColor(.white.opacity(0.8))
                Text("\(viewModel.currentUser?.points ?? 0) pts").font(.system(size: 24, weight: .heavy)).foregroundColor(.white)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("STAMPS").font(.system(size: 11, weight: .bold)).foregroundColor(.white.opacity(0.8))
                Text("\(viewModel.currentUser?.stamps ?? 0)/10").font(.system(size: 24, weight: .heavy)).foregroundColor(.white)
            }
        }
        .padding(18)
        .background(AppColors.primaryGreen)
        .cornerRadius(16)
    }

    private func rewardCard(_ reward: Reward) -> some View {
        let alreadyRedeemed = redeemedIds.contains(reward.id)
        let canAfford = (reward.costInPoints == 0 || (viewModel.currentUser?.points ?? 0) >= reward.costInPoints)
                      && (reward.costInStamps == 0 || (viewModel.currentUser?.stamps ?? 0) >= reward.costInStamps)

        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(red: 0xE8/255.0, green: 0xF5/255.0, blue: 0xE9/255.0)).frame(width: 48, height: 48)
                Image(systemName: "gift.fill").font(.system(size: 20)).foregroundColor(AppColors.primaryGreen)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(reward.title).font(.system(size: 15, weight: .bold)).foregroundColor(AppColors.darkGreen)
                if !reward.description.isEmpty {
                    Text(reward.description).font(.system(size: 12)).foregroundColor(.gray).lineLimit(2)
                }
                Text(costDescription(reward)).font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.primaryGreen)
            }
            Spacer()

            Button(action: { confirmingReward = reward }) {
                Text(alreadyRedeemed ? "Redeemed" : "Redeem")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(alreadyRedeemed || !canAfford ? Color.gray.opacity(0.5) : AppColors.primaryGreen)
                    .cornerRadius(10)
            }
            .disabled(alreadyRedeemed || !canAfford || isRedeeming)
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }

    private func costDescription(_ reward: Reward) -> String {
        var parts: [String] = []
        if reward.costInPoints > 0 { parts.append("\(reward.costInPoints) pts") }
        if reward.costInStamps > 0 { parts.append("\(reward.costInStamps) stamps") }
        return parts.isEmpty ? "Free" : parts.joined(separator: " + ")
    }

    private func redeem(_ reward: Reward) {
        isRedeeming = true
        Task {
            await viewModel.redeemReward(reward)
            await refreshRedeemed()
            await MainActor.run {
                isRedeeming = false
                confirmingReward = nil
            }
        }
    }

    private func refreshRedeemed() async {
        let redeemed = await viewModel.fetchMyRedeemedRewards()
        await MainActor.run {
            redeemedIds = Set(redeemed.map { $0.id })
        }
    }
}
