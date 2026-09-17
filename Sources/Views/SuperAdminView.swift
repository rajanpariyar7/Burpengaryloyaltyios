import SwiftUI

struct SuperAdminView: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    private let brandGreen = Color(red: 0.30, green: 0.58, blue: 0.24)

    var body: some View {
        TabView {
            SuperAdminConfigTab(viewModel: viewModel)
                .tabItem { Label("Config", systemImage: "gearshape.fill") }
            SuperAdminRolesTab(viewModel: viewModel)
                .tabItem { Label("Roles", systemImage: "person.2.badge.gearshape.fill") }
            SuperAdminTransactionsTab(viewModel: viewModel)
                .tabItem { Label("Transactions", systemImage: "list.bullet.rectangle") }
            SuperAdminAuditTab(viewModel: viewModel)
                .tabItem { Label("Audit", systemImage: "clock.arrow.circlepath") }
        }
        .accentColor(brandGreen)
    }
}

// MARK: - Config (global thresholds + the write-enable lock only Super Admin controls)

struct SuperAdminConfigTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @State private var pointsPerDollar = "10"
    @State private var redemptionThreshold = "100"
    @State private var discountPer100 = "1.0"
    @State private var adminWriteEnabled = false
    @State private var cashierLoginEnabled = true
    @State private var cashierLoginStartTime = "08:00"
    @State private var cashierLoginEndTime = "18:00"
    private let brandGreen = Color(red: 0.30, green: 0.58, blue: 0.24)

    var body: some View {
        NavigationView {
            Form {
                Section("Global Loyalty Configuration") {
                    TextField("Points Earned per $1 Spent", text: $pointsPerDollar).keyboardType(.numberPad)
                    TextField("Minimum Points to Redeem", text: $redemptionThreshold).keyboardType(.numberPad)
                    TextField("Discount Value per 100 Points ($)", text: $discountPer100).keyboardType(.decimalPad)
                }

                Section("Admin Write Access") {
                    Toggle("Allow Admins to Edit Loyalty Rules", isOn: $adminWriteEnabled)
                    Text("When off, Admin's Loyalty Engine Configuration screen is locked.")
                        .font(.caption).foregroundColor(.gray)
                }

                Section("Cashier Access Control") {
                    Toggle("Enable Cashier Login", isOn: $cashierLoginEnabled)
                    if cashierLoginEnabled {
                        TextField("Login Start Time (HH:mm)", text: $cashierLoginStartTime)
                        TextField("Login End Time (HH:mm)", text: $cashierLoginEndTime)
                    }
                }

                Button("Save Configuration") {
                    viewModel.updateSettings(
                        pointsPerDollar: Int(pointsPerDollar) ?? 10,
                        discountPer100Points: Double(discountPer100) ?? 1.0,
                        redemptionThreshold: Int(redemptionThreshold) ?? 100,
                        adminWriteEnabled: adminWriteEnabled,
                        cashierLoginEnabled: cashierLoginEnabled,
                        cashierLoginStartTime: cashierLoginStartTime,
                        cashierLoginEndTime: cashierLoginEndTime
                    )
                }
                .foregroundColor(brandGreen)

                if let error = viewModel.errorMessage {
                    Text(error).foregroundColor(.red).font(.footnote)
                }
                if let success = viewModel.successMessage {
                    Text(success).foregroundColor(brandGreen).font(.footnote)
                }
            }
            .navigationTitle("Global Config")
            .onAppear { syncFromSettings() }
        }
        .navigationViewStyle(.stack)
    }

    private func syncFromSettings() {
        guard let s = viewModel.pointSettings else { return }
        pointsPerDollar = "\(s.pointsPerDollar)"
        redemptionThreshold = "\(s.redemptionThreshold)"
        discountPer100 = "\(s.discountPer100Points)"
        adminWriteEnabled = s.adminWriteEnabled
        cashierLoginEnabled = s.cashierLoginEnabled
        cashierLoginStartTime = s.cashierLoginStartTime
        cashierLoginEndTime = s.cashierLoginEndTime
    }
}

// MARK: - Roles (add/remove roles for any user + create a cashier account)

struct SuperAdminRolesTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @State private var roleSheetUser: User?
    @State private var showCreateCashier = false
    private let brandGreen = Color(red: 0.30, green: 0.58, blue: 0.24)

    var body: some View {
        NavigationView {
            List(viewModel.allUsers) { user in
                Button(action: { roleSheetUser = user }) {
                    HStack {
                        Circle()
                            .fill(Color(UIColor.systemGray5))
                            .frame(width: 44, height: 44)
                            .overlay(Text(String(user.name.first ?? "U")).fontWeight(.bold))
                        VStack(alignment: .leading) {
                            Text(user.name).fontWeight(.bold).foregroundColor(.primary)
                            Text(user.email).font(.caption).foregroundColor(.gray)
                        }
                        Spacer()
                        Text(user.role.rawValue)
                            .font(.caption2).fontWeight(.bold)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(roleColor(user.role))
                            .foregroundColor(user.role == .customer ? .black.opacity(0.7) : .white)
                            .cornerRadius(8)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Role & Permissions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateCashier = true }) {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(item: $roleSheetUser) { user in
                RoleChangeSheet(viewModel: viewModel, user: user)
            }
            .sheet(isPresented: $showCreateCashier) {
                CreateCashierSheet(viewModel: viewModel)
            }
        }
        .navigationViewStyle(.stack)
    }

    private func roleColor(_ role: Role) -> Color {
        switch role {
        case .superAdmin: return .black
        case .admin: return brandGreen
        case .cashier: return .orange
        case .customer: return Color(UIColor.systemGray4)
        }
    }
}

struct RoleChangeSheet: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    let user: User
    @State private var selectedRole: Role
    @Environment(\.dismiss) private var dismiss
    private let brandGreen = Color(red: 0.30, green: 0.58, blue: 0.24)

    init(viewModel: LoyaltyViewModel, user: User) {
        self.viewModel = viewModel
        self.user = user
        _selectedRole = State(initialValue: user.role)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Select a new role for \(user.email)") {
                    ForEach(Role.allCases, id: \.self) { role in
                        HStack {
                            Text(role.rawValue)
                            Spacer()
                            if role == selectedRole {
                                Image(systemName: "checkmark").foregroundColor(brandGreen)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedRole = role }
                    }
                }
            }
            .navigationTitle("Change Role")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        viewModel.changeUserRole(email: user.email, newRole: selectedRole)
                        dismiss()
                    }
                    .foregroundColor(brandGreen)
                }
            }
        }
    }
}

struct CreateCashierSheet: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    private let brandGreen = Color(red: 0.30, green: 0.58, blue: 0.24)

    var body: some View {
        NavigationView {
            Form {
                TextField("Full Name", text: $name)
                TextField("Email", text: $email).textInputAutocapitalization(.never).autocorrectionDisabled(true)
                SecureField("Temporary Password", text: $password)
                if let error = viewModel.errorMessage {
                    Text(error).foregroundColor(.red).font(.footnote)
                }
            }
            .navigationTitle("New Cashier")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        viewModel.createCashier(email: email, name: name, pass: password)
                        dismiss()
                    }
                    .foregroundColor(brandGreen)
                    .disabled(name.isEmpty || email.isEmpty || password.isEmpty)
                }
            }
        }
    }
}

// MARK: - Transactions (full system-wide ledger)

struct SuperAdminTransactionsTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    private let formatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM dd, yyyy HH:mm"; return f
    }()

    var body: some View {
        NavigationView {
            List(viewModel.allTransactions) { tx in
                HStack {
                    Image(systemName: tx.pointChange > 0 ? "arrow.up" : "arrow.down")
                        .foregroundColor(tx.pointChange > 0 ? .green : .red)
                    VStack(alignment: .leading) {
                        Text(tx.description).font(.footnote).fontWeight(.semibold)
                        Text(tx.userEmail).font(.caption2).foregroundColor(.gray)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(tx.pointChange > 0 ? "+" : "")\(tx.pointChange)")
                            .fontWeight(.bold)
                            .foregroundColor(tx.pointChange > 0 ? .green : .red)
                        Text(formatter.string(from: tx.date)).font(.caption2).foregroundColor(.gray)
                    }
                }
            }
            .listStyle(.plain)
            .overlay { if viewModel.allTransactions.isEmpty { Text("No transactions recorded yet.").foregroundColor(.gray) } }
            .navigationTitle("Point Transactions")
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Audit log

struct SuperAdminAuditTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    private let formatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM dd, yyyy HH:mm:ss"; return f
    }()

    var body: some View {
        NavigationView {
            List(viewModel.auditLogs) { log in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Action:").font(.caption).fontWeight(.bold).foregroundColor(.gray)
                        Spacer()
                        Text(formatter.string(from: Date(timeIntervalSince1970: Double(log.timestamp) / 1000)))
                            .font(.caption).foregroundColor(.gray)
                    }
                    Text(log.action).fontWeight(.bold)
                    Text("By: \(log.changedBy)").font(.caption).foregroundColor(.green)
                }
                .padding(.vertical, 4)
            }
            .listStyle(.plain)
            .overlay { if viewModel.auditLogs.isEmpty { Text("No logs recorded yet.").foregroundColor(.gray) } }
            .navigationTitle("System Audit Logs")
        }
        .navigationViewStyle(.stack)
    }
}
