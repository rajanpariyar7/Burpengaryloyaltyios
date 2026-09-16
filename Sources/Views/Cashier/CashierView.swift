import SwiftUI

struct CashierView: View {
    @ObservedObject var viewModel: LoyaltyViewModel

    var body: some View {
        TabView {
            CashierScanTab(viewModel: viewModel)
                .tabItem { Label("Scan", systemImage: "qrcode.viewfinder") }
            CashierHistoryTab(viewModel: viewModel)
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
        }
        .tint(Palette.primaryGreen)
        .notificationAlert(viewModel)
    }
}

struct CashierScanTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel

    @State private var query = ""
    @State private var selectedEmail: String?
    @State private var purchaseAmount = ""
    @State private var redeemPoints = ""
    @State private var isScanning = false

    private var settings: PointSettings { viewModel.pointSettings ?? PointSettings() }

    private var selectedCustomer: User? {
        guard let selectedEmail else { return nil }
        return viewModel.allUsers.first { $0.email == selectedEmail }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(title: "Register", subtitle: "Scan or search a customer to add points")

                HStack(spacing: 10) {
                    SearchField(placeholder: "Name, email, phone or member ID", text: $query)
                    Button {
                        isScanning.toggle()
                    } label: {
                        Image(systemName: isScanning ? "xmark" : "qrcode.viewfinder")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(Palette.primaryGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                if isScanning {
                    BarcodeScannerView { code in
                        query = code
                        selectedEmail = matchedEmail(for: code)
                        isScanning = false
                    }
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                if selectedCustomer == nil, !query.isEmpty {
                    ForEach(viewModel.searchUsers(query: query)) { user in
                        Button {
                            selectedEmail = user.email
                            query = ""
                        } label: {
                            CardContainer(padding: 14) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(user.name.isEmpty ? user.email : user.name)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundColor(Palette.extraDarkGreen)
                                        Text(user.email).font(.caption).foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Text("\(user.points) pts")
                                        .font(.subheadline.weight(.heavy))
                                        .foregroundColor(Palette.primaryGreen)
                                }
                            }
                        }
                    }
                }

                if let customer = selectedCustomer {
                    customerPanel(customer)
                }
            }
            .padding(20)
        }
        .background(Palette.neutralBackground.ignoresSafeArea())
    }

    private func matchedEmail(for code: String) -> String? {
        viewModel.allUsers.first { $0.email == code || $0.customerId == code || $0.phone == code }?.email
    }

    @ViewBuilder
    private func customerPanel(_ customer: User) -> some View {
        let rewardValue = Double(customer.points) / 100.0 * settings.discountPer100Points

        CardContainer {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(customer.name.isEmpty ? "Customer" : customer.name)
                            .font(.title3.weight(.bold))
                            .foregroundColor(Palette.extraDarkGreen)
                        Text(customer.email).font(.caption).foregroundColor(.gray)
                    }
                    Spacer()
                    Button("Clear") { selectedEmail = nil }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Palette.negativeRed)
                }
                Divider()
                HStack {
                    Text("\(customer.points) points")
                        .font(.headline)
                        .foregroundColor(Palette.primaryGreen)
                    Spacer()
                    Text(String(format: "Worth $%.2f", rewardValue))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Palette.accentOrange)
                }
                Text("Stamps: \(customer.stamps)/10")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }

        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("Complete purchase")
                    .font(.headline)
                    .foregroundColor(Palette.extraDarkGreen)
                TextField("Purchase amount ($)", text: $purchaseAmount)
                    .keyboardType(.decimalPad)
                    .padding(12)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.borderSlate))
                Text("Earns \(Int((Double(purchaseAmount) ?? 0) * Double(settings.pointsPerDollar))) points at \(settings.pointsPerDollar) pts / $1")
                    .font(.caption)
                    .foregroundColor(.gray)
                Button("Add Points") {
                    guard let amount = Double(purchaseAmount), amount > 0 else { return }
                    viewModel.processPurchase(customerEmail: customer.email, amount: amount)
                    purchaseAmount = ""
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Add Stamp") {
                    viewModel.addStamp(to: customer.email)
                }
                .buttonStyle(PrimaryButtonStyle(background: Palette.accentOrange))
            }
        }

        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("Redeem points")
                    .font(.headline)
                    .foregroundColor(Palette.extraDarkGreen)
                TextField("Points to redeem", text: $redeemPoints)
                    .keyboardType(.numberPad)
                    .padding(12)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.borderSlate))
                Text(String(
                    format: "Discount: $%.2f — minimum %d points",
                    Double(Int(redeemPoints) ?? 0) / 100.0 * settings.discountPer100Points,
                    settings.redemptionThreshold
                ))
                .font(.caption)
                .foregroundColor(.gray)
                Button("Apply Discount") {
                    guard let points = Int(redeemPoints),
                          points >= settings.redemptionThreshold,
                          points <= customer.points else {
                        viewModel.notify("Error", "Enter between \(settings.redemptionThreshold) and \(customer.points) points.")
                        return
                    }
                    viewModel.redeemPointsAsCashier(email: customer.email, points: points)
                    redeemPoints = ""
                }
                .buttonStyle(PrimaryButtonStyle(background: Palette.deepOrange))
            }
        }
    }
}

struct CashierHistoryTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Register History", subtitle: "Recent point activity across the store")
                ForEach(viewModel.allTransactions.prefix(100)) { transaction in
                    TransactionRow(transaction: transaction, showCustomer: true)
                }
                if viewModel.allTransactions.isEmpty {
                    Text("No transactions recorded yet.").font(.subheadline).foregroundColor(.gray)
                }
            }
            .padding(20)
        }
        .background(Palette.neutralBackground.ignoresSafeArea())
    }
}
