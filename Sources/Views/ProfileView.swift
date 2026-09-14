import SwiftUI

struct ProfileView: View {
    let user: AppUser
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Name", value: user.name)
                    LabeledContent("Email", value: user.email)
                    LabeledContent("Role", value: user.role.displayName)
                    if !user.phone.isEmpty {
                        LabeledContent("Phone", value: user.phone)
                    }
                }

                Section("Balance") {
                    LabeledContent("Stamps", value: "\(user.stamps)")
                    LabeledContent("Points", value: "\(user.points)")
                    LabeledContent("Lifetime stamps", value: "\(user.lifetimeStamps)")
                }

                Section {
                    Button("Sign out", role: .destructive) {
                        authViewModel.signOut()
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}
