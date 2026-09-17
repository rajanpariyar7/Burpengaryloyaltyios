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
        .accentColor(Color(red: 0.30, green: 0.58, blue: 0.24))
    }
}

struct CashierScanTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @State private var searchQuery = ""
    @State private var selectedCustomer: User?
    @State private var purchaseAmount = ""
    @State private var pointsToRedeem = ""
    @State private var isScanningMode = false

    private let brandGreen = Color(red: 0.30, green: 0.58, blue: 0.24)

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let user = selectedCustomer {
                    customerPanel(user)
                } else {
                    Picker("", selection: $isScanningMode) {
                        Text("Search Customer").tag(false)
                        Text("Scan QR / Barcode").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    if isScanningMode {
                        ZStack {
                            BarcodeScannerView { scanned in
                                searchQuery = scanned
                                isScanningMode = false
                                if let match = viewModel.searchUsers(scanned).first(where: { $0.email == scanned }) {
                                    selectedCustomer = match
                                }
                            }
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(brandGreen, lineWidth: 4)
                                .frame(width: 250, height: 250)
                        }
                    } else {
                        searchPanel
                    }
                }
            }
            .navigationTitle("Cashier")
            .background(Color(UIColor.systemGroupedBackground))
        }
        .navigationViewStyle(.stack)
    }

    private var searchPanel: some View {
        VStack {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Search by Name, Phone, Email, or ID", text: $searchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }
            .padding(10)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(UIColor.separator), lineWidth: 1))
            .padding(.horizontal)

            let results = viewModel.searchUsers(searchQuery)
            List(results) { user in
                Button(action: {
                    selectedCustomer = user
                    searchQuery = ""
                }) {
                    HStack {
                        Circle()
                            .fill(brandGreen.opacity(0.15))
                            .frame(width: 40, height: 40)
                            .overlay(Text(String(user.name.first ?? "C")).foregroundColor(brandGreen).fontWeight(.bold))
                        VStack(alignment: .leading) {
                            Text(user.name).fontWeight(.bold)
                            Text(user.phone.isEmpty ? user.email : user.phone)
                                .font(.caption).foregroundColor(.gray)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
            .listStyle(.plain)
        }
    }

    private func customerPanel(_ user: User) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button(action: { selectedCustomer = nil }) {
                    Label("Back to Search", systemImage: "arrow.left")
                }
                .padding(.horizontal)

                let discountRate = viewModel.pointSettings?.discountPer100Points ?? 1.0
                let rewardValue = (Double(user.points) / 100.0) * discountRate

                VStack(alignment: .leading, spacing: 12) {
                    Label("Customer Identified", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(user.name).font(.title3).fontWeight(.bold).foregroundColor(.white)
                    Text(user.phone.isEmpty ? user.email : user.phone).foregroundColor(.white.opacity(0.7))
                    HStack {
                        VStack(alignment: .leading) {
                            Text("POINTS").font(.caption).foregroundColor(.gray)
                            Text("\(user.points)").font(.title).fontWeight(.bold).foregroundColor(.white)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("REWARD VALUE").font(.caption).foregroundColor(.gray)
                            Text(String(format: "$%.2f", rewardValue)).font(.title).fontWeight(.bold).foregroundColor(.orange)
                        }
                    }
                }
                .padding()
                .background(Color(red: 0.05, green: 0.15, blue: 0.05))
                .cornerRadius(16)
                .padding(.horizontal)

                if let error = viewModel.errorMessage {
                    Text(error).foregroundColor(.red).font(.footnote).padding(.horizontal)
                }
                if let success = viewModel.successMessage {
                    Text(success).foregroundColor(brandGreen).font(.footnote).padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Process Purchase").fontWeight(.bold).foregroundColor(brandGreen)
                    TextField("Purchase Amount ($)", text: $purchaseAmount)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: {
                        let amount = Double(purchaseAmount) ?? 0
                        viewModel.processPurchase(customerEmail: user.email, amount: amount)
                        purchaseAmount = ""
                    }) {
                        Text("Complete Purchase & Add Points")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(brandGreen)
                            .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(UIColor.separator)))
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Redeem Points").fontWeight(.bold).foregroundColor(brandGreen)
                    Text("Minimum 100 points for discount.").font(.caption).foregroundColor(.gray)
                    TextField("Points to Redeem (e.g. 100, 200)", text: $pointsToRedeem)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: {
                        let points = Int(pointsToRedeem) ?? 0
                        if points > 0 && user.points >= points {
                            viewModel.redeemPointsCashier(email: user.email, points: points)
                            pointsToRedeem = ""
                        } else {
                            viewModel.errorMessage = "Invalid points or insufficient balance."
                        }
                    }) {
                        Text("Redeem & Apply Discount")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(UIColor.separator)))
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

struct CashierHistoryTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel

    private var myTransactions: [PointTransaction] {
        let email = viewModel.currentUser?.email ?? ""
        return viewModel.allTransactions
            .filter { $0.description.localizedCaseInsensitiveContains(email) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM dd, yyyy HH:mm"
        return f
    }()

    var body: some View {
        NavigationView {
            List(myTransactions) { tx in
                HStack {
                    Image(systemName: tx.pointChange > 0 ? "arrow.up" : "arrow.down")
                        .foregroundColor(tx.pointChange > 0 ? .green : .red)
                        .frame(width: 36, height: 36)
                        .background((tx.pointChange > 0 ? Color.green : Color.red).opacity(0.12))
                        .cornerRadius(8)
                    VStack(alignment: .leading) {
                        Text(tx.userEmail).fontWeight(.bold)
                        Text(tx.description).font(.caption).foregroundColor(.gray)
                        Text(formatter.string(from: tx.date)).font(.caption2).foregroundColor(.gray)
                    }
                    Spacer()
                    Text("\(tx.pointChange > 0 ? "+" : "")\(tx.pointChange)")
                        .fontWeight(.heavy)
                        .foregroundColor(tx.pointChange > 0 ? .green : .red)
                }
            }
            .navigationTitle("Your Register History")
            .overlay {
                if myTransactions.isEmpty {
                    Text("No transactions found.").foregroundColor(.gray)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
