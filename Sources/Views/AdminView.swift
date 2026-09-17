import SwiftUI

struct AdminView: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    private let darkGreen = Color(red: 0.05, green: 0.2, blue: 0.05)
    private let brandGreen = Color(red: 0.30, green: 0.58, blue: 0.24)

    var body: some View {
        TabView {
            AdminStatsTab(viewModel: viewModel)
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
            AdminOffersTab(viewModel: viewModel)
                .tabItem { Label("Offers", systemImage: "tag.fill") }
            AdminTransactionsTab(viewModel: viewModel)
                .tabItem { Label("Audit", systemImage: "list.bullet.rectangle") }
            AdminCustomersTab(viewModel: viewModel)
                .tabItem { Label("Customers", systemImage: "person.2.fill") }
            AdminSettingsTab(viewModel: viewModel)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .accentColor(brandGreen)
    }
}

// MARK: - Stats

struct AdminStatsTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    private let darkGreen = Color(red: 0.05, green: 0.2, blue: 0.05)

    private var pointsToday: (added: Int, redeemed: Int) {
        let cal = Calendar.current
        let todays = viewModel.allTransactions.filter { cal.isDateInToday($0.date) }
        let added = todays.filter { $0.pointChange > 0 }.reduce(0) { $0 + $1.pointChange }
        let redeemed = todays.filter { $0.pointChange < 0 }.reduce(0) { $0 + abs($1.pointChange) }
        return (added, redeemed)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Overview of loyalty program performance.")
                        .font(.footnote).foregroundColor(.gray).padding(.horizontal)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        statCard("Total Customers", "\(viewModel.allCustomers.count)")
                        statCard("Active Offers", "\(viewModel.offers.count)")
                        statCard("Points Issued Today", "\(pointsToday.added)")
                        statCard("Points Redeemed Today", "\(pointsToday.redeemed)")
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Store Dashboard")
        }
        .navigationViewStyle(.stack)
    }

    private func statCard(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value).font(.title).fontWeight(.heavy).foregroundColor(darkGreen)
            Text(title).font(.caption).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(UIColor.separator)))
    }
}

// MARK: - Offers (catalog + manage)

struct AdminOffersTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @State private var mode = 0 // 0 = Catalog, 1 = Manage

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $mode) {
                    Text("Catalog").tag(0)
                    Text("Manage").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if mode == 0 {
                    AdminCatalogGrid(viewModel: viewModel)
                } else {
                    AdminManageForm(viewModel: viewModel)
                }
            }
            .navigationTitle("Offers Manager")
        }
        .navigationViewStyle(.stack)
    }
}

struct AdminCatalogGrid: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @State private var selectedCategory = "ALL"
    private let brandGreen = Color(red: 0.30, green: 0.58, blue: 0.24)
    private let darkGreen = Color(red: 0.05, green: 0.2, blue: 0.05)

    private var categoryNames: [String] {
        ["ALL"] + Set(viewModel.categories.map { $0.name.uppercased() }).sorted()
    }

    private var filteredOffers: [Offer] {
        selectedCategory == "ALL" ? viewModel.offers : viewModel.offers.filter { $0.category.uppercased() == selectedCategory }
    }

    var body: some View {
        ScrollView {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categoryNames, id: \.self) { cat in
                        Text(cat)
                            .font(.caption).fontWeight(.bold)
                            .foregroundColor(cat == selectedCategory ? .white : .primary)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(cat == selectedCategory ? darkGreen : Color.white)
                            .cornerRadius(20)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(UIColor.separator)))
                            .onTapGesture { selectedCategory = cat }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(filteredOffers) { offer in
                    VStack(alignment: .leading, spacing: 6) {
                        ZStack(alignment: .topTrailing) {
                            Rectangle()
                                .fill(Color(UIColor.systemGray5))
                                .frame(height: 110)
                                .overlay(Image(systemName: "photo").foregroundColor(.gray))
                            Button(action: { viewModel.deleteOffer(offer) }) {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.red)
                                    .padding(6)
                                    .background(Color.white.opacity(0.8))
                                    .clipShape(Circle())
                            }
                            .padding(4)
                        }
                        Text(offer.title).font(.footnote).fontWeight(.bold).lineLimit(2)
                        Text(offer.price).font(.subheadline).fontWeight(.bold).foregroundColor(brandGreen)
                    }
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(UIColor.separator)))
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

struct AdminManageForm: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @State private var newCategoryName = ""
    @State private var offerTitle = ""
    @State private var offerCategory = ""
    @State private var offerPrice = ""
    @State private var offerDesc = ""
    private let brandGreen = Color(red: 0.30, green: 0.58, blue: 0.24)
    private let darkGreen = Color(red: 0.05, green: 0.2, blue: 0.05)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Manage Categories").font(.title3).fontWeight(.bold).foregroundColor(darkGreen)

                HStack {
                    TextField("New Category", text: $newCategoryName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Add") {
                        guard !newCategoryName.isEmpty else { return }
                        viewModel.addCategory(newCategoryName.uppercased())
                        newCategoryName = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(brandGreen)
                }

                Text("Existing Categories").font(.footnote).fontWeight(.bold)
                if viewModel.categories.isEmpty {
                    Text("No categories yet.").font(.caption).foregroundColor(.gray)
                } else {
                    ForEach(viewModel.categories) { cat in
                        HStack {
                            Text(cat.name)
                            Spacer()
                            Button(action: { viewModel.deleteCategory(cat) }) {
                                Image(systemName: "trash").foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error).foregroundColor(.red).font(.footnote)
                }
                if let success = viewModel.successMessage {
                    Text(success).foregroundColor(brandGreen).font(.footnote)
                }

                Divider().padding(.vertical, 8)

                Text("Add New Offer").font(.title3).fontWeight(.bold).foregroundColor(darkGreen)
                TextField("Product Title", text: $offerTitle).textFieldStyle(RoundedBorderTextFieldStyle())

                Picker("Category", selection: $offerCategory) {
                    Text("General").tag("")
                    ForEach(viewModel.categories) { cat in
                        Text(cat.name).tag(cat.name)
                    }
                }
                .pickerStyle(.menu)

                TextField("Price (e.g. $2.99)", text: $offerPrice).textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Description", text: $offerDesc, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button(action: {
                    viewModel.addOffer(title: offerTitle, price: offerPrice, description: offerDesc, category: offerCategory)
                    offerTitle = ""; offerPrice = ""; offerDesc = ""; offerCategory = ""
                }) {
                    Text("Publish Product")
                        .fontWeight(.bold).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(brandGreen).cornerRadius(12)
                }
            }
            .padding()
        }
    }
}

// MARK: - Transactions / Audit (points added & redeemed report)

struct AdminTransactionsTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @State private var section = 0 // 0 all, 1 added, 2 redeemed
    @State private var search = ""
    private let brandGreen = Color(red: 0.30, green: 0.58, blue: 0.24)

    private let formatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM dd, yyyy HH:mm"; return f
    }()

    private var filtered: [PointTransaction] {
        var txs = viewModel.allTransactions
        if section == 1 { txs = txs.filter { $0.pointChange > 0 } }
        if section == 2 { txs = txs.filter { $0.pointChange < 0 } }
        if !search.isEmpty {
            txs = txs.filter { $0.description.localizedCaseInsensitiveContains(search) || $0.userEmail.localizedCaseInsensitiveContains(search) }
        }
        return txs
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Text("Detailed report of points added and redeemed by cashiers.")
                    .font(.footnote).foregroundColor(.gray).padding([.horizontal, .top])

                Picker("", selection: $section) {
                    Text("All").tag(0)
                    Text("Points Added").tag(1)
                    Text("Points Redeemed").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                List(filtered) { tx in
                    HStack {
                        Image(systemName: tx.pointChange > 0 ? "arrow.up" : "arrow.down")
                            .foregroundColor(tx.pointChange > 0 ? .green : .red)
                        VStack(alignment: .leading) {
                            Text(tx.description).font(.footnote).fontWeight(.semibold)
                            Text("Customer: \(tx.userEmail)").font(.caption2).foregroundColor(.gray)
                            Text(formatter.string(from: tx.date)).font(.caption2).foregroundColor(.gray)
                        }
                        Spacer()
                        Text("\(tx.pointChange > 0 ? "+" : "")\(tx.pointChange)")
                            .fontWeight(.bold)
                            .foregroundColor(tx.pointChange > 0 ? .green : .red)
                    }
                }
                .listStyle(.plain)
                .overlay { if filtered.isEmpty { Text("No transactions found.").foregroundColor(.gray) } }
            }
            .navigationTitle("Point Transactions")
            .searchable(text: $search, prompt: "Search cashier email or description")
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Customers

struct AdminCustomersTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @State private var query = ""
    private let brandGreen = Color(red: 0.30, green: 0.58, blue: 0.24)

    private var results: [User] {
        query.isEmpty ? viewModel.allCustomers : viewModel.allCustomers.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.email.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationView {
            List(results) { customer in
                HStack {
                    VStack(alignment: .leading) {
                        Text(customer.name).fontWeight(.bold)
                        Text(customer.email).font(.caption).foregroundColor(.gray)
                    }
                    Spacer()
                    Text("\(customer.points) pts").fontWeight(.heavy).foregroundColor(brandGreen)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Customer Database")
            .searchable(text: $query, prompt: "Search by name or email")
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Settings (cashier access control + loyalty engine thresholds)

struct AdminSettingsTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @State private var pointsPerDollar = "10"
    @State private var redemptionThreshold = "100"
    @State private var discountPer100 = "1.0"
    @State private var cashierLoginEnabled = true
    @State private var cashierLoginStartTime = "08:00"
    @State private var cashierLoginEndTime = "18:00"
    private let brandGreen = Color(red: 0.30, green: 0.58, blue: 0.24)
    private let darkGreen = Color(red: 0.05, green: 0.2, blue: 0.05)

    private var isWriteEnabled: Bool { viewModel.pointSettings?.adminWriteEnabled ?? false }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Text(viewModel.currentUser?.name ?? "").fontWeight(.bold)
                    }
                }

                Section("Cashier Access Control") {
                    Toggle("Enable Cashier Login", isOn: $cashierLoginEnabled)
                    if cashierLoginEnabled {
                        TextField("Login Start Time (HH:mm)", text: $cashierLoginStartTime)
                        TextField("Login End Time (HH:mm)", text: $cashierLoginEndTime)
                        Text("Format: 24-hour time (e.g. 08:00, 18:00)").font(.caption).foregroundColor(.gray)
                    }
                    Button("Save Cashier Schedule") { save() }
                        .foregroundColor(brandGreen)
                }

                Section("Loyalty Engine Configuration") {
                    if !isWriteEnabled {
                        Label("Settings are locked. Contact Super Admin to modify point rules.", systemImage: "lock.fill")
                            .font(.caption).foregroundColor(.red)
                    }
                    TextField("Points Earned per $1 Spent", text: $pointsPerDollar)
                        .keyboardType(.numberPad).disabled(!isWriteEnabled)
                    TextField("Minimum Points to Redeem", text: $redemptionThreshold)
                        .keyboardType(.numberPad).disabled(!isWriteEnabled)
                    TextField("Discount Value per 100 Points ($)", text: $discountPer100)
                        .keyboardType(.decimalPad).disabled(!isWriteEnabled)
                    Button("Save Loyalty Rules & Feature Flags") { save() }
                        .disabled(!isWriteEnabled)
                        .foregroundColor(isWriteEnabled ? brandGreen : .gray)
                }

                if let error = viewModel.errorMessage {
                    Text(error).foregroundColor(.red).font(.footnote)
                }
                if let success = viewModel.successMessage {
                    Text(success).foregroundColor(brandGreen).font(.footnote)
                }
            }
            .navigationTitle("Settings")
            .onAppear { syncFromSettings() }
            .onChange(of: viewModel.pointSettings?.pointsPerDollar) { _ in syncFromSettings() }
        }
        .navigationViewStyle(.stack)
    }

    private func syncFromSettings() {
        guard let s = viewModel.pointSettings else { return }
        pointsPerDollar = "\(s.pointsPerDollar)"
        redemptionThreshold = "\(s.redemptionThreshold)"
        discountPer100 = "\(s.discountPer100Points)"
        cashierLoginEnabled = s.cashierLoginEnabled
        cashierLoginStartTime = s.cashierLoginStartTime
        cashierLoginEndTime = s.cashierLoginEndTime
    }

    private func save() {
        viewModel.updateSettings(
            pointsPerDollar: Int(pointsPerDollar) ?? 10,
            discountPer100Points: Double(discountPer100) ?? 1.0,
            redemptionThreshold: Int(redemptionThreshold) ?? 100,
            adminWriteEnabled: isWriteEnabled,
            cashierLoginEnabled: cashierLoginEnabled,
            cashierLoginStartTime: cashierLoginStartTime,
            cashierLoginEndTime: cashierLoginEndTime
        )
    }
}
