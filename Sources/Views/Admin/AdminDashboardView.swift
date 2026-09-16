import SwiftUI

struct AdminDashboardView: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    let admin: User

    var body: some View {
        TabView {
            AdminStatsTab(viewModel: viewModel)
                .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
            AdminOffersTab(viewModel: viewModel)
                .tabItem { Label("Offers", systemImage: "tag.fill") }
            AdminTransactionsTab(viewModel: viewModel)
                .tabItem { Label("Transactions", systemImage: "list.bullet.rectangle") }
            AdminCustomersTab(viewModel: viewModel)
                .tabItem { Label("Customers", systemImage: "person.2.fill") }
            AdminSettingsTab(viewModel: viewModel, admin: admin)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Palette.primaryGreen)
        .notificationAlert(viewModel)
    }
}

struct AdminStatsTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel

    private var startOfDay: Int64 {
        Int64(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970 * 1000)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Store Dashboard", subtitle: "Overview of loyalty program performance.")

                let today = viewModel.allTransactions.filter { $0.timestamp >= startOfDay }
                let issued = today.filter { $0.pointChange > 0 }.reduce(0) { $0 + $1.pointChange }
                let redeemed = today.filter { $0.pointChange < 0 }.reduce(0) { $0 - $1.pointChange }

                HStack(spacing: 16) {
                    StatCard(value: "\(viewModel.allCustomers.count)", label: "Total Customers")
                    StatCard(value: "\(viewModel.offers.count)", label: "Active Offers", tint: Palette.accentOrange)
                }
                HStack(spacing: 16) {
                    StatCard(value: "\(issued)", label: "Points Issued Today")
                    StatCard(value: "\(redeemed)", label: "Points Redeemed Today", tint: Palette.negativeRed)
                }
            }
            .padding(20)
        }
        .background(Palette.neutralBackground.ignoresSafeArea())
    }
}

struct AdminOffersTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel

    @State private var showAddForm = false
    @State private var title = ""
    @State private var price = ""
    @State private var description = ""
    @State private var imageUrl = ""
    @State private var category = "General"
    @State private var newCategory = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    SectionHeader(title: "Offers Manager")
                    Button(showAddForm ? "Close" : "Add Offer") { showAddForm.toggle() }
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Palette.primaryGreen)
                        .clipShape(Capsule())
                }

                if showAddForm {
                    addForm
                    categoryManager
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(viewModel.offers) { offer in
                        VStack(spacing: 8) {
                            OfferCard(offer: offer)
                            Button("Delete") { viewModel.deleteOffer(offer) }
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Palette.negativeRed)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Palette.neutralBackground.ignoresSafeArea())
    }

    private var addForm: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("New offer").font(.headline).foregroundColor(Palette.extraDarkGreen)
                textField("Title", text: $title)
                textField("Price (e.g. $2.99)", text: $price)
                textField("Description", text: $description)
                textField("Image URL (optional)", text: $imageUrl)

                Picker("Category", selection: $category) {
                    Text("General").tag("General")
                    ForEach(viewModel.categories) { item in
                        Text(item.name).tag(item.name)
                    }
                }
                .pickerStyle(.menu)
                .tint(Palette.primaryGreen)

                Button("Publish offer") {
                    guard !title.isEmpty else { return }
                    viewModel.addOffer(
                        title: title,
                        price: price,
                        description: description,
                        category: category,
                        imageUrl: imageUrl.isEmpty ? nil : imageUrl
                    )
                    title = ""; price = ""; description = ""; imageUrl = ""
                    showAddForm = false
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var categoryManager: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("Categories").font(.headline).foregroundColor(Palette.extraDarkGreen)
                HStack {
                    textField("New category", text: $newCategory)
                    Button("Add") {
                        guard !newCategory.isEmpty else { return }
                        viewModel.addCategory(name: newCategory)
                        newCategory = ""
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Palette.primaryGreen)
                }
                ForEach(viewModel.categories) { item in
                    HStack {
                        Text(item.name).font(.subheadline)
                        Spacer()
                        Button("Remove") { viewModel.deleteCategory(item) }
                            .font(.caption)
                            .foregroundColor(Palette.negativeRed)
                    }
                }
            }
        }
    }

    private func textField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .padding(12)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.borderSlate))
    }
}

struct AdminTransactionsTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel

    @State private var filter = ""
    @State private var section = 0

    private var transactions: [PointTransaction] {
        let base: [PointTransaction]
        switch section {
        case 1: base = viewModel.allTransactions.filter { $0.pointChange > 0 }
        case 2: base = viewModel.allTransactions.filter { $0.pointChange < 0 }
        default: base = viewModel.allTransactions
        }
        guard !filter.isEmpty else { return base }
        return base.filter {
            $0.description.localizedCaseInsensitiveContains(filter)
                || $0.userEmail.localizedCaseInsensitiveContains(filter)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: "Point Transactions",
                    subtitle: "Detailed report of points added and redeemed by cashiers."
                )
                Picker("Section", selection: $section) {
                    Text("All").tag(0)
                    Text("Added").tag(1)
                    Text("Redeemed").tag(2)
                }
                .pickerStyle(.segmented)

                SearchField(placeholder: "Search cashier email or description", text: $filter)

                ForEach(transactions) { transaction in
                    TransactionRow(transaction: transaction, showCustomer: true)
                }
                if transactions.isEmpty {
                    Text("No transactions found.").font(.subheadline).foregroundColor(.gray)
                }
            }
            .padding(20)
        }
        .background(Palette.neutralBackground.ignoresSafeArea())
    }
}

struct AdminCustomersTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @State private var query = ""

    private var customers: [User] {
        guard !query.isEmpty else { return viewModel.allCustomers }
        return viewModel.allCustomers.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.email.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Customer Database", subtitle: "View and search customer profiles.")
                SearchField(placeholder: "Search by name or email", text: $query)

                ForEach(customers) { customer in
                    CardContainer(padding: 16) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle().fill(Palette.backgroundLight).frame(width: 40, height: 40)
                                Text(String(customer.name.first ?? "C"))
                                    .font(.headline)
                                    .foregroundColor(Palette.darkGreen)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(customer.name).font(.subheadline.weight(.bold)).foregroundColor(Palette.darkGreen)
                                Text(customer.email).font(.caption).foregroundColor(.gray)
                            }
                            Spacer()
                            Text("\(customer.points) pts")
                                .font(.subheadline.weight(.heavy))
                                .foregroundColor(Palette.primaryGreen)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Palette.neutralBackground.ignoresSafeArea())
    }
}

struct AdminSettingsTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    let admin: User

    @State private var pointsPerDollar = ""
    @State private var redemptionThreshold = ""
    @State private var discountPer100 = ""
    @State private var cashierLoginEnabled = true
    @State private var cashierStart = "08:00"
    @State private var cashierEnd = "18:00"

    @State private var cashierEmail = ""
    @State private var cashierName = ""
    @State private var cashierPassword = ""

    private var settings: PointSettings { viewModel.pointSettings ?? PointSettings() }
    private var isWriteEnabled: Bool { settings.adminWriteEnabled }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle().fill(Palette.primaryGreen).frame(width: 64, height: 64)
                        Image(systemName: "person.fill").font(.title).foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(admin.name).font(.title3.weight(.bold)).foregroundColor(Palette.extraDarkGreen)
                        Text("STORE MANAGER").font(.caption2.weight(.bold)).tracking(1).foregroundColor(.gray)
                    }
                }

                SectionHeader(title: "Cashier Access Control")
                CardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable Cashier Login", isOn: $cashierLoginEnabled)
                            .tint(Palette.primaryGreen)
                        if cashierLoginEnabled {
                            labelledField("Login Start Time (HH:mm)", text: $cashierStart)
                            labelledField("Login End Time (HH:mm)", text: $cashierEnd)
                            Text("Format: 24-hour time (e.g. 08:00, 18:00)")
                                .font(.caption2).foregroundColor(.gray)
                        }
                        Button("Save Cashier Schedule") { save() }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                }

                SectionHeader(title: "Loyalty Engine Configuration")
                CardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        if !isWriteEnabled {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.fill").foregroundColor(Palette.negativeRed)
                                Text("Settings are locked. Contact Super Admin to modify point rules.")
                                    .font(.caption).foregroundColor(Palette.negativeRed)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.negativeTint)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        labelledField("Points Earned per $1 Spent", text: $pointsPerDollar, keyboard: .numberPad)
                        labelledField("Minimum Points to Redeem", text: $redemptionThreshold, keyboard: .numberPad)
                        labelledField("Discount Value per 100 Points ($)", text: $discountPer100, keyboard: .decimalPad)
                        Button("Save Loyalty Rules") { save() }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(!isWriteEnabled)
                    }
                }

                SectionHeader(title: "Create Cashier")
                CardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        labelledField("Cashier name", text: $cashierName)
                        labelledField("Cashier email", text: $cashierEmail, keyboard: .emailAddress)
                        labelledField("Temporary password", text: $cashierPassword)
                        Button("Create cashier account") {
                            viewModel.createCashier(email: cashierEmail, name: cashierName, password: cashierPassword)
                            cashierEmail = ""; cashierName = ""; cashierPassword = ""
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
        .onAppear(perform: loadSettings)
        .onChange(of: viewModel.pointSettings) { _ in loadSettings() }
    }

    private func loadSettings() {
        pointsPerDollar = "\(settings.pointsPerDollar)"
        redemptionThreshold = "\(settings.redemptionThreshold)"
        discountPer100 = "\(settings.discountPer100Points)"
        cashierLoginEnabled = settings.cashierLoginEnabled
        cashierStart = settings.cashierLoginStartTime
        cashierEnd = settings.cashierLoginEndTime
    }

    private func save() {
        viewModel.updateSettings(
            pointsPerDollar: Int(pointsPerDollar) ?? 10,
            discountPer100Points: Double(discountPer100) ?? 1.0,
            redemptionThreshold: Int(redemptionThreshold) ?? 100,
            adminWriteEnabled: isWriteEnabled,
            cashierLoginEnabled: cashierLoginEnabled,
            cashierLoginStartTime: cashierStart,
            cashierLoginEndTime: cashierEnd
        )
    }

    private func labelledField(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.gray)
            TextField(label, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.borderSlate))
        }
    }
}
