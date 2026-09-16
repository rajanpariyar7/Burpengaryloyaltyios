import SwiftUI

struct SuperAdminDashboardView: View {
    @ObservedObject var viewModel: LoyaltyViewModel

    var body: some View {
        TabView {
            SuperAdminConfigTab(viewModel: viewModel)
                .tabItem { Label("Config", systemImage: "slider.horizontal.3") }
            SuperAdminRolesTab(viewModel: viewModel)
                .tabItem { Label("Roles", systemImage: "person.badge.key.fill") }
            AdminTransactionsTab(viewModel: viewModel)
                .tabItem { Label("Transactions", systemImage: "list.bullet.rectangle") }
            SuperAdminAuditTab(viewModel: viewModel)
                .tabItem { Label("Audit", systemImage: "doc.text.magnifyingglass") }
        }
        .tint(Palette.primaryGreen)
        .notificationAlert(viewModel)
    }
}

struct SuperAdminConfigTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel

    @State private var pointsPerDollar = ""
    @State private var redemptionThreshold = ""
    @State private var discountPer100 = ""
    @State private var adminWriteEnabled = true

    private var settings: PointSettings { viewModel.pointSettings ?? PointSettings() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Global Configuration", subtitle: "Loyalty engine rules for the whole store.")

                CardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        field("Points per $1 spent", text: $pointsPerDollar, keyboard: .numberPad)
                        field("Minimum points to redeem", text: $redemptionThreshold, keyboard: .numberPad)
                        field("Discount per 100 points ($)", text: $discountPer100, keyboard: .decimalPad)
                        Toggle("Allow admins to edit point rules", isOn: $adminWriteEnabled)
                            .tint(Palette.primaryGreen)
                        Button("Save configuration") {
                            viewModel.updateSettings(
                                pointsPerDollar: Int(pointsPerDollar) ?? 10,
                                discountPer100Points: Double(discountPer100) ?? 1.0,
                                redemptionThreshold: Int(redemptionThreshold) ?? 100,
                                adminWriteEnabled: adminWriteEnabled,
                                cashierLoginEnabled: settings.cashierLoginEnabled,
                                cashierLoginStartTime: settings.cashierLoginStartTime,
                                cashierLoginEndTime: settings.cashierLoginEndTime
                            )
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }

                Button("Sign Out") { viewModel.logout() }
                    .buttonStyle(PrimaryButtonStyle(background: Palette.negativeRed))
            }
            .padding(20)
        }
        .background(Palette.neutralBackground.ignoresSafeArea())
        .onAppear(perform: load)
        .onChange(of: viewModel.pointSettings) { _ in load() }
    }

    private func load() {
        pointsPerDollar = "\(settings.pointsPerDollar)"
        redemptionThreshold = "\(settings.redemptionThreshold)"
        discountPer100 = "\(settings.discountPer100Points)"
        adminWriteEnabled = settings.adminWriteEnabled
    }

    private func field(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.gray)
            TextField(label, text: text)
                .keyboardType(keyboard)
                .padding(12)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.borderSlate))
        }
    }
}

struct SuperAdminRolesTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @State private var query = ""

    private var users: [User] {
        guard !query.isEmpty else { return viewModel.allUsers }
        return viewModel.allUsers.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.email.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Roles & Permissions", subtitle: "Promote or demote any account.")
                SearchField(placeholder: "Search users", text: $query)

                ForEach(users) { user in
                    CardContainer(padding: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(user.name.isEmpty ? user.email : user.name)
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(Palette.extraDarkGreen)
                            Text(user.email).font(.caption).foregroundColor(.gray)
                            Picker("Role", selection: Binding(
                                get: { user.role },
                                set: { viewModel.changeUserRole(email: user.email, role: $0) }
                            )) {
                                ForEach(Role.allCases, id: \.self) { role in
                                    Text(role.rawValue).tag(role)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Palette.primaryGreen)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Palette.neutralBackground.ignoresSafeArea())
    }
}

struct SuperAdminAuditTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "System Audit Logs", subtitle: "Immutable trail of setting and role changes.")
                ForEach(viewModel.auditLogs) { log in
                    CardContainer(padding: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Action:").font(.caption.weight(.bold)).foregroundColor(.gray)
                                Spacer()
                                Text(log.date, format: .dateTime.day().month().year().hour().minute())
                                    .font(.caption).foregroundColor(.gray)
                            }
                            Text(log.action)
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(Palette.extraDarkGreen)
                            Text("By: \(log.changedBy)")
                                .font(.caption)
                                .foregroundColor(Palette.mediumGreen)
                        }
                    }
                }
                if viewModel.auditLogs.isEmpty {
                    Text("No logs recorded yet.").font(.subheadline).foregroundColor(.gray)
                }
            }
            .padding(20)
        }
        .background(Palette.neutralBackground.ignoresSafeArea())
    }
}
