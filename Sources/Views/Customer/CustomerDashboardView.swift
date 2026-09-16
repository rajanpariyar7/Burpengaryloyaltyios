import SwiftUI

struct CustomerDashboardView: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    let user: User

    var body: some View {
        TabView {
            CustomerHomeTab(viewModel: viewModel, user: user)
                .tabItem { Label("Home", systemImage: "house.fill") }
            CustomerIDTab(user: user)
                .tabItem { Label("ID", systemImage: "qrcode") }
            CustomerCatalogTab(viewModel: viewModel, user: user)
                .tabItem { Label("Catalog", systemImage: "cart.fill") }
            CustomerHistoryTab(viewModel: viewModel, user: user)
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            CustomerProfileTab(viewModel: viewModel, user: user)
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .tint(Palette.primaryGreen)
        .notificationAlert(viewModel)
    }
}

// MARK: - Home

struct CustomerHomeTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    let user: User

    private var rewardValue: Double {
        let settings = viewModel.pointSettings ?? PointSettings()
        return Double(user.points) / 100.0 * settings.discountPer100Points
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Welcome back,")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text(user.name.isEmpty ? "Valued Customer" : user.name)
                            .font(.title2.weight(.bold))
                            .foregroundColor(Palette.extraDarkGreen)
                    }
                    Spacer()
                    Image(systemName: "bell.fill")
                        .foregroundColor(Palette.primaryGreen)
                        .padding(10)
                        .background(Palette.lightGreenCard)
                        .clipShape(Circle())
                }

                MembershipCardView(user: user)

                HStack(spacing: 16) {
                    StatCard(value: "\(user.points)", label: "Loyalty Points")
                    StatCard(
                        value: String(format: "$%.2f", rewardValue),
                        label: "Reward Value",
                        tint: Palette.accentOrange
                    )
                }

                DigitalPunchCard(stamps: user.stamps)

                if !viewModel.offers.isEmpty {
                    SectionHeader(title: "Promotions", subtitle: "Fresh deals in store right now")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(viewModel.offers.prefix(6)) { offer in
                                OfferCard(offer: offer)
                                    .frame(width: 200)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Palette.neutralBackground.ignoresSafeArea())
    }
}

// MARK: - ID

struct CustomerIDTab: View {
    let user: User

    private var memberCode: String { user.customerId.isEmpty ? user.email : user.customerId }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SectionHeader(title: "Membership ID", subtitle: "Scan at the register")

                CardContainer {
                    VStack(spacing: 20) {
                        QRCodeView(value: memberCode, size: 220)
                        BarcodeView(value: memberCode, height: 90)
                        Text(memberCode)
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Palette.extraDarkGreen)
                    }
                    .frame(maxWidth: .infinity)
                }

                CardContainer {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(user.name)
                            .font(.headline)
                            .foregroundColor(Palette.extraDarkGreen)
                        Text(user.email).font(.subheadline).foregroundColor(.gray)
                        if !user.phone.isEmpty {
                            Text(user.phone).font(.subheadline).foregroundColor(.gray)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Palette.neutralBackground.ignoresSafeArea())
    }
}

// MARK: - Catalog

struct CustomerCatalogTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    let user: User

    @State private var selectedCategory = "All"

    private var categories: [String] {
        ["All"] + Array(Set(viewModel.offers.map(\.category))).sorted()
    }

    private var filteredOffers: [Offer] {
        selectedCategory == "All" ? viewModel.offers : viewModel.offers.filter { $0.category == selectedCategory }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    SectionHeader(title: "Catalog", subtitle: "Offers and vouchers")
                    Text("\(user.points) pts")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Palette.primaryGreen)
                        .clipShape(Capsule())
                }

                if !viewModel.rewards.isEmpty {
                    Text("Vouchers")
                        .font(.headline)
                        .foregroundColor(Palette.extraDarkGreen)
                    ForEach(viewModel.rewards) { reward in
                        RewardCard(reward: reward, user: user, settings: viewModel.pointSettings ?? PointSettings()) {
                            viewModel.redeemReward(reward)
                        }
                    }
                }

                Text("Offers")
                    .font(.headline)
                    .foregroundColor(Palette.extraDarkGreen)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { category in
                            Button(category) { selectedCategory = category }
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selectedCategory == category ? Palette.primaryGreen : Color.white)
                                .foregroundColor(selectedCategory == category ? .white : Palette.extraDarkGreen)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Palette.borderSlate))
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(filteredOffers) { offer in
                        OfferCard(offer: offer)
                    }
                }

                if filteredOffers.isEmpty {
                    Text("No offers available right now.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding(20)
        }
        .background(Palette.neutralBackground.ignoresSafeArea())
    }
}

struct RewardCard: View {
    let reward: Reward
    let user: User
    let settings: PointSettings
    let onRedeem: () -> Void

    private var canRedeem: Bool {
        if reward.costInStamps > 0 { return user.stamps >= reward.costInStamps }
        return user.points >= reward.costInPoints && user.points >= settings.redemptionThreshold
    }

    private var cost: String {
        reward.costInStamps > 0 ? "\(reward.costInStamps) stamps" : "\(reward.costInPoints) points"
    }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                Text(reward.title)
                    .font(.headline)
                    .foregroundColor(Palette.extraDarkGreen)
                Text(reward.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack {
                    Text(cost)
                        .font(.caption.weight(.bold))
                        .foregroundColor(Palette.primaryGreen)
                    Spacer()
                    Button("Redeem", action: onRedeem)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(canRedeem ? Palette.primaryGreen : Color.gray.opacity(0.4))
                        .clipShape(Capsule())
                        .disabled(!canRedeem)
                }
            }
        }
    }
}

struct OfferCard: View {
    let offer: Offer

    var body: some View {
        CardContainer(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                if let imageUrl = offer.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Palette.lightGreenCard
                    }
                    .frame(height: 110)
                    .clipped()
                } else {
                    ZStack {
                        Palette.lightGreenCard
                        Image(systemName: "leaf.fill")
                            .font(.title)
                            .foregroundColor(Palette.primaryGreen)
                    }
                    .frame(height: 110)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(offer.category.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Palette.accentOrange)
                    Text(offer.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Palette.extraDarkGreen)
                        .lineLimit(2)
                    Text(offer.price)
                        .font(.subheadline.weight(.heavy))
                        .foregroundColor(Palette.primaryGreen)
                    if !offer.description.isEmpty {
                        Text(offer.description)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                }
                .padding(12)
            }
        }
    }
}

// MARK: - History

struct CustomerHistoryTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    let user: User

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Points Activity", subtitle: "Everything you have earned and redeemed")

                let transactions = viewModel.transactions(for: user.email)
                if transactions.isEmpty {
                    Text("No activity yet. Start shopping to earn points!")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                } else {
                    ForEach(transactions) { transaction in
                        TransactionRow(transaction: transaction)
                    }
                }
            }
            .padding(20)
        }
        .background(Palette.neutralBackground.ignoresSafeArea())
    }
}

// MARK: - Profile

struct CustomerProfileTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    let user: User

    @State private var currentPassword = ""
    @State private var newPassword = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(title: "Profile")

                CardContainer {
                    VStack(alignment: .leading, spacing: 8) {
                        row("Name", user.name)
                        row("Email", user.email)
                        if !user.phone.isEmpty { row("Phone", user.phone) }
                        row("Membership", user.customerId.isEmpty ? user.email : user.customerId)
                        row("Lifetime stamps", "\(user.lifetimeStamps)")
                    }
                }

                CardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Change password")
                            .font(.headline)
                            .foregroundColor(Palette.extraDarkGreen)
                        SecureField("Current password", text: $currentPassword)
                            .padding(12)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.borderSlate))
                        SecureField("New password", text: $newPassword)
                            .padding(12)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.borderSlate))
                        Button("Update password") {
                            viewModel.changeOwnPassword(currentPassword: currentPassword, newPassword: newPassword)
                            currentPassword = ""
                            newPassword = ""
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(currentPassword.isEmpty || newPassword.count < 6)
                    }
                }

                Button("Sign Out") { viewModel.logout() }
                    .buttonStyle(PrimaryButtonStyle(background: Palette.negativeRed))
            }
            .padding(20)
        }
        .background(Palette.neutralBackground.ignoresSafeArea())
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.gray)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).foregroundColor(Palette.extraDarkGreen)
        }
    }
}
