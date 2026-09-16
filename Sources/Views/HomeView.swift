import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: LoyaltyViewModel

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let user = viewModel.currentUser {
                    Text("Welcome, \(user.name.isEmpty ? user.email : user.name)!")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 24) {
                        VStack {
                            Text("\(user.points)")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            Text("Points")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        VStack {
                            Text("\(user.stamps)")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            Text("Stamps")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                } else {
                    ProgressView()
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Burpengary Market")
        }
    }
}
