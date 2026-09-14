import SwiftUI

struct OffersView: View {
    @StateObject private var viewModel = OffersViewModel()

    var body: some View {
        NavigationStack {
            List {
                if let error = viewModel.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
                ForEach(viewModel.offers) { offer in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(offer.title).font(.headline)
                            Spacer()
                            Text(offer.price)
                                .font(.subheadline).bold()
                        }
                        Text(offer.category)
                            .font(.caption2).bold()
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(.orange.opacity(0.15))
                            .clipShape(Capsule())
                        Text(offer.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Offers")
            .overlay {
                if viewModel.isLoading { ProgressView() }
            }
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
        }
    }
}
