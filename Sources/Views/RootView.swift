import SwiftUI

struct RootView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        Group {
            if authViewModel.isAuthenticated, let user = authViewModel.currentUser {
                MainTabView(user: user)
            } else {
                LoginView()
            }
        }
    }
}
