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

            switch viewModel.currentUser?.role {
            case .cashier:
                CashierView(viewModel: viewModel)
                    .tabItem { Label("Cashier", systemImage: "qrcode.viewfinder") }
            case .admin:
                AdminView(viewModel: viewModel)
                    .tabItem { Label("Admin", systemImage: "wrench.and.screwdriver.fill") }
            case .superAdmin:
                SuperAdminView(viewModel: viewModel)
                    .tabItem { Label("Super Admin", systemImage: "crown.fill") }
            default:
                EmptyView()
            }

            ProfileView(viewModel: viewModel)
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .accentColor(Color(red: 0.30, green: 0.58, blue: 0.24))
    }
}
