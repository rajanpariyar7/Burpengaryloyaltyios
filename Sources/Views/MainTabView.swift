import SwiftUI

struct MainTabView: View {
    let user: AppUser

    var body: some View {
        TabView {
            HomeView(user: user)
                .tabItem { Label("Home", systemImage: "house.fill") }

            RewardsView()
                .tabItem { Label("Rewards", systemImage: "star.fill") }

            OffersView()
                .tabItem { Label("Offers", systemImage: "tag.fill") }

            // CASHIER, ADMIN, SUPER_ADMIN get an extra tab — matches the
            // Android app's role-gated staff screens.
            if user.role.isStaff {
                StaffToolsView()
                    .tabItem { Label("Staff Tools", systemImage: "person.badge.key.fill") }
            }

            // ADMIN, SUPER_ADMIN only — cashier login window, loyalty rules.
            if user.role.canManageSettings {
                AdminSettingsView()
                    .tabItem { Label("Admin", systemImage: "gearshape.fill") }
            }

            ProfileView(user: user)
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
        }
    }
}
