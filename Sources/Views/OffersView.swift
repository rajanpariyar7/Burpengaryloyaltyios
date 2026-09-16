import SwiftUI
import FirebaseFirestore

struct OffersView: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @State private var offers: [Offer] = []
    private let db = Firestore.firestore()

    var body: some View {
        NavigationView {
            List(offers) { offer in
                VStack(alignment: .leading, spacing: 4) {
                    Text(offer.title).font(.headline)
                    Text(offer.category)
                        .font(.caption)
                        .foregroundColor(.green)
                    if !offer.description.isEmpty {
                        Text(offer.description)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    if !offer.price.isEmpty {
                        Text(offer.price)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Offers")
            .onAppear(perform: fetchOffers)
        }
    }

    private func fetchOffers() {
        db.collection("offers").addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error fetching offers: \(error)")
                return
            }
            self.offers = snapshot?.documents.compactMap { try? $0.data(as: Offer.self) } ?? []
        }
    }
}
