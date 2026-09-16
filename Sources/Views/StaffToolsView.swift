import SwiftUI

struct StaffToolsView: View {
    @ObservedObject var viewModel: LoyaltyViewModel

    var body: some View {
        NavigationView {
            List {
                Section("Staff Tools") {
                    Text("Wire this up to your Cashier/Admin/Super Admin features: awarding points or stamps, redeeming rewards, and managing offers. Gate individual actions further by checking viewModel.currentUser?.role.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Staff Tools")
        }
    }
}
