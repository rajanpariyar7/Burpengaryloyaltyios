import SwiftUI

// Super Admin only: "super admin can give roles to admins and cashiers".
// Gated in two places: BurpengaryApp.swift only shows this tab for
// .superAdmin, and firestore/firestore.rules in this zip rejects role writes
// from anyone else server-side (the client-side gate alone isn't enough —
// anyone could otherwise edit the app or call Firestore directly).
struct AdminRolesView: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @State private var query = ""

    private var filteredUsers: [User] {
        let others = viewModel.allUsers.filter { $0.email != viewModel.currentUser?.email }
        guard !query.isEmpty else { return others }
        return others.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.email.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(filteredUsers) { user in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(user.name).font(.system(size: 15, weight: .bold)).foregroundColor(AppColors.darkGreen)
                            Text(user.email).font(.system(size: 12)).foregroundColor(.gray)
                        }
                        Spacer()
                        Picker("", selection: Binding(
                            get: { user.role },
                            set: { newRole in
                                Task { await viewModel.updateUserRole(email: user.email, role: newRole) }
                            }
                        )) {
                            ForEach(Role.allCases, id: \.self) { role in
                                Text(role.displayName).tag(role)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.vertical, 4)
                }
            }
            .searchable(text: $query, prompt: "Search by name or email")
            .navigationTitle("Manage Roles")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
