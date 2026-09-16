import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: LoyaltyViewModel

    var body: some View {
        NavigationView {
            Form {
                if let user = viewModel.currentUser {
                    Section("Account") {
                        LabeledContent("Name", value: user.name)
                        LabeledContent("Email", value: user.email)
                        LabeledContent("Phone", value: user.phone)
                        LabeledContent("Role", value: user.role.rawValue)
                    }
                }
                Section {
                    Button("Log Out", role: .destructive) {
                        viewModel.logout()
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}
