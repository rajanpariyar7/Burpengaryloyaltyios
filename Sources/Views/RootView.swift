import SwiftUI

/// Role based router, matching the Android `MainActivity` destinations.
struct RootView: View {
    @ObservedObject var viewModel: LoyaltyViewModel

    var body: some View {
        if let user = viewModel.currentUser {
            switch user.role {
            case .customer:
                CustomerDashboardView(viewModel: viewModel, user: user)
            case .cashier:
                CashierView(viewModel: viewModel)
            case .admin:
                AdminDashboardView(viewModel: viewModel, admin: user)
            case .superAdmin:
                SuperAdminDashboardView(viewModel: viewModel)
            }
        } else {
            LoginView(viewModel: viewModel)
        }
    }
}
