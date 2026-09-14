import SwiftUI

struct RewardsView: View {
    @StateObject private var viewModel = RewardsViewModel()

    var body: some View {
        NavigationStack {
            List {
                if let error = viewModel.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
                ForEach(viewModel.rewards) { reward in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(reward.title).font(.headline)
                        Text(reward.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text(reward.costDisplay)
                                .font(.caption).bold()
                            Spacer()
                            Button("Redeem") {
                                Task { await viewModel.redeem(reward) }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Rewards")
            .overlay {
                if viewModel.isLoading { ProgressView() }
            }
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
        }
    }
}
