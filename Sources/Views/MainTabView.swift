import SwiftUI

struct MainTabView: View {
    @ObservedObject var viewModel: LoyaltyViewModel

    var body: some View {
        TabView {
            HomeView(viewModel: viewModel)
                .tabItem { Label("Home", systemImage: "house.fill") }

            RewardsView(viewModel: viewModel)
                .tabItem { Label("Rewards", systemImage: "gift.fill") }

            OffersView(viewModel: viewModel)
                .tabItem { Label("Offers", systemImage: "tag.fill") }

            if let role = viewModel.currentUser?.role, role != .customer {
                StaffToolsView(viewModel: viewModel)
                    .tabItem { Label("Staff", systemImage: "wrench.and.screwdriver.fill") }
            }

            ProfileView(viewModel: viewModel)
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .accentColor(.green)
    }
}
