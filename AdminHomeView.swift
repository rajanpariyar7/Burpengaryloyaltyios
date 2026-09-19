import SwiftUI

// Role-gated tab bar for anyone who isn't a plain Customer.
//  - Cashier:     Offers (add-only, see AdminOffersView's isCashier check) + Profile
//  - Admin:       Offers (full CRUD) + Notifications + Profile
//  - Super Admin: Offers + Notifications + Roles + Profile
struct AdminHomeView: View {
    @ObservedObject var viewModel: LoyaltyViewModel

    var body: some View {
        TabView {
            AdminOffersView(viewModel: viewModel)
                .tabItem { Label("Offers", systemImage: "bag.fill") }

            if viewModel.currentUser?.role == .admin || viewModel.currentUser?.role == .superAdmin {
                AdminNotificationsView(viewModel: viewModel)
                    .tabItem { Label("Notify", systemImage: "bell.fill") }
            }

            if viewModel.currentUser?.role == .superAdmin {
                AdminRolesView(viewModel: viewModel)
                    .tabItem { Label("Roles", systemImage: "person.2.fill") }
            }

            ProfileView(viewModel: viewModel)
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .tint(AppColors.primaryGreen)
    }
}
