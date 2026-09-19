//
//  CustomerDashboardScreen.swift
//  Burpengary Loyalty
//
//  1:1 SwiftUI translation of CustomerDashboardScreen.kt
//  (app/src/main/java/com/example/CustomerDashboardScreen.kt)
//
//  Wired against what's ALREADY in this repo's ios_source/ folder:
//    - Models.swift        -> User, Reward, Offer, PointSettings (unchanged, used as-is)
//    - Models+Transactions.swift -> PointTransaction (new — Models.swift had no equivalent)
//    - LoyaltyViewModel.swift    -> extended with offers/pointSettings/allTransactions/
//                                   logOfferClick/sendNotification/changeUserPassword/
//                                   redeemReward(Reward) (all missing from the original skeleton)
//    - LoginView.swift's AppColors -> reused + extended below instead of a second theme struct
//
//  COLOR NOTE: the request asked for #2E7D32 / #1B5E20. The actual Android source
//  (ui/theme/Color.kt) — and LoginView.swift's own AppColors, already in this repo —
//  both use #5A8F3A / #1A241B instead. This file follows what's already in the repo
//  so Login and Dashboard stay visually consistent. Two more colors are used only
//  inline in CustomerDashboardScreen.kt (not in Color.kt): the scaffold background
//  #F3F4F1 and the loyalty-card green #2C5E3B ("Forest Green" per the Kotlin comment).
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Theme additions (AppColors itself lives in LoginView.swift)

extension AppColors {
    static let accentOrange     = Color(red: 0xFF/255.0, green: 0xA7/255.0, blue: 0x26/255.0)
    static let lightGreenCard   = Color(red: 0xD5/255.0, green: 0xE8/255.0, blue: 0xD4/255.0)
    static let screenBackground = Color(red: 0xF3/255.0, green: 0xF4/255.0, blue: 0xF1/255.0)
    static let loyaltyCardGreen = Color(red: 0x2C/255.0, green: 0x5E/255.0, blue: 0x3B/255.0)
    static let cartBubbleBg     = Color(red: 0xFC/255.0, green: 0xE4/255.0, blue: 0xEC/255.0)
    static let cartBubbleTint   = Color(red: 0xD8/255.0, green: 0x1B/255.0, blue: 0x60/255.0)
    static let avatarCircleBg   = Color(red: 0xD4/255.0, green: 0xE1/255.0, blue: 0xD4/255.0)
    static let rewardIconBg     = Color(red: 0xFF/255.0, green: 0xF3/255.0, blue: 0xE0/255.0)
    static let historyDebitBg   = Color(red: 0xFF/255.0, green: 0xEB/255.0, blue: 0xEE/255.0)
    static let historyDebitTint = Color(red: 0xD3/255.0, green: 0x2F/255.0, blue: 0x2F/255.0)
}

// MARK: - Barcode / QR generation (Kotlin: BarcodeUtils.kt — QR_CODE + CODE_128, matched here)

enum CodeGenerator {
    static func generateQRCode(from string: String, size: CGFloat = 400) -> UIImage? {
        guard !string.isEmpty else { return nil }
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let scale = size / outputImage.extent.width
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    static func generateBarcode(from string: String, width: CGFloat = 600, height: CGFloat = 200) -> UIImage? {
        guard !string.isEmpty else { return nil }
        let context = CIContext()
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(string.utf8)
        filter.quietSpace = 4
        guard let outputImage = filter.outputImage else { return nil }
        let scaleX = width / outputImage.extent.width
        let scaleY = height / outputImage.extent.height
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Root screen (Kotlin: CustomerDashboardScreen)

struct CustomerDashboardScreen: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.screenBackground.ignoresSafeArea()

            Group {
                switch selectedTab {
                case 0: CustomerHomeTab(viewModel: viewModel)
                case 1: CustomerQRTab(customer: viewModel.currentUser)
                case 2: RewardsView(viewModel: viewModel)
                case 3: CustomerCatalogTab(viewModel: viewModel)
                case 4: CustomerHistoryTab(viewModel: viewModel)
                default: ProfileView(viewModel: viewModel)
                }
            }
            .padding(.bottom, 80) // reserve space for the custom bottom bar

            BFMBottomBar(selectedTab: $selectedTab)
        }
        // Kotlin requests POST_NOTIFICATIONS on Android 13+ inside this screen.
        // iOS equivalent (UNUserNotificationCenter authorization) belongs in
        // BurpengaryApp.swift's AppDelegate, alongside FirebaseApp.configure(),
        // not per-screen — no onAppear call needed here.
    }
}

// MARK: - Bottom bar (Kotlin: Scaffold.bottomBar { NavigationBar ... })

private struct BFMBottomBar: View {
    @Binding var selectedTab: Int

    private let items: [(filled: String, outline: String, label: String)] = [
        ("square.grid.2x2.fill", "square.grid.2x2", "Home"),
        ("qrcode", "qrcode", "ID"),
        ("gift.fill", "gift", "Rewards"),
        ("bag.fill", "bag", "Catalog"),
        ("clock.arrow.circlepath", "clock.arrow.circlepath", "History"),
        ("person.fill", "person", "Profile")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                let item = items[i]
                let isSelected = selectedTab == i
                Button(action: { selectedTab = i }) {
                    VStack(spacing: 2) {
                        Image(systemName: isSelected ? item.filled : item.outline)
                            .font(.system(size: 20))
                        Text(item.label)
                            .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                    }
                    .foregroundColor(isSelected ? AppColors.darkGreen : .gray)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 80)
        .background(
            RoundedCorner(radius: 24, corners: [.topLeft, .topRight])
                .fill(Color.white)
                .shadow(color: .black.opacity(0.15), radius: 8, y: -2)
        )
    }
}

/// Helper for rounding only the top corners (Kotlin: RoundedCornerShape(topStart, topEnd))
private struct RoundedCorner: Shape {
    var radius: CGFloat = 0
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Home tab (Kotlin: CustomerHomeTab)

struct CustomerHomeTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @State private var selectedCodeType: String = "Barcode" // "Barcode" | "QR Code" | "Scannable"

    private var customer: User? { viewModel.currentUser }
    private var offers: [Offer] { viewModel.offers }
    private var pointSettings: PointSettings? { viewModel.pointSettings }

    private var customerPoints: Int { customer?.points ?? 0 }
    private var discountRate: Double { pointSettings?.discountPer100Points ?? 1.0 }
    private var rewardValue: Double { (Double(customerPoints) / 100.0) * discountRate }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                greetingRow
                    .padding(.top, 16)
                Spacer().frame(height: 24)

                loyaltyCard
                Spacer().frame(height: 24)

                pointsAndRewardRow
                Spacer().frame(height: 24)

                promotionsHeader
                Spacer().frame(height: 16)

                offersGrid
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    private var greetingRow: some View {
        HStack {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(AppColors.cartBubbleBg).frame(width: 40, height: 40)
                    Image(systemName: "cart.fill")
                        .foregroundColor(AppColors.cartBubbleTint)
                        .font(.system(size: 18))
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("BURPENGARY LOYALTY")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                        .tracking(1)
                    let firstName = customer?.name.components(separatedBy: " ").first ?? "Guest"
                    Text("G'day, \(firstName)! 👋")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.black)
                }
            }
            Spacer()
            ZStack(alignment: .topTrailing) {
                Circle().fill(Color.white).frame(width: 40, height: 40)
                Image(systemName: "bell")
                    .foregroundColor(.black)
                    .font(.system(size: 22))
                    .frame(width: 40, height: 40)
                Circle()
                    .fill(AppColors.accentOrange)
                    .frame(width: 14, height: 14)
                    .overlay(Text("2").font(.system(size: 8, weight: .bold)).foregroundColor(.white))
                    .padding(2)
            }
        }
    }

    private var loyaltyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("MEMBERSHIP CARD")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .tracking(1)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").font(.system(size: 14)).foregroundColor(.white)
                    Text("\(customerPoints) PTS")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppColors.accentOrange)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Spacer().frame(height: 8)
            Text("Burpengary Market Gold")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Spacer().frame(height: 24)

            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(AppColors.avatarCircleBg).frame(width: 48, height: 48)
                    let initial = customer?.name.first.map { String($0).uppercased() } ?? "G"
                    Text(initial)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppColors.loyaltyCardGreen)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(customer?.name ?? "Guest")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    // Kotlin: customer?.email?.hashCode()?.toString()?.takeLast(6)
                    // Swift's String.hashValue is NOT equivalent to Java's
                    // String.hashCode(), so this shows a *different* 6-digit ID than
                    // Android for the same email. If the ID must match across
                    // platforms, port Java's hashCode algorithm explicitly, or use the
                    // `customerId` field User already has but that nothing populates yet.
                    let customerId = String(String(abs((customer?.email ?? "guest").hashValue)).suffix(6))
                    Text("ID: BFM-\(customerId)")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            Spacer().frame(height: 24)

            codeDisplay

            Spacer().frame(height: 16)

            HStack(spacing: 8) {
                ToggleBtn(text: "Barcode", systemImage: "square.stack.3d.up",
                          isSelected: selectedCodeType == "Barcode",
                          action: { selectedCodeType = "Barcode" })
                ToggleBtn(text: "QR Code", systemImage: "qrcode",
                          isSelected: selectedCodeType == "QR Code",
                          action: { selectedCodeType = "QR Code" })
                ToggleBtn(text: "SCANNABLE", systemImage: "viewfinder",
                          isSelected: true, isOrange: true, action: {})
            }
        }
        .padding(24)
        .background(AppColors.loyaltyCardGreen)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var codeDisplay: some View {
        let emailStr = customer?.email ?? "guest"
        return RoundedRectangle(cornerRadius: 12)
            .fill(Color.white)
            .frame(height: 120)
            .overlay(
                Group {
                    if selectedCodeType == "QR Code" {
                        if let qr = CodeGenerator.generateQRCode(from: emailStr, size: 400) {
                            Image(uiImage: qr)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .padding(12)
                        }
                    } else {
                        VStack(spacing: 4) {
                            if let barcode = CodeGenerator.generateBarcode(from: emailStr, width: 600, height: 200) {
                                Image(uiImage: barcode)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                            }
                            Text(emailStr)
                                .font(.system(size: 10))
                                .foregroundColor(.black)
                        }
                        .padding(12)
                    }
                }
            )
    }

    private var pointsAndRewardRow: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: "star")
                        .foregroundColor(.black)
                    Spacer()
                    Text("EARNING")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.accentOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Spacer().frame(height: 16)
                Text("POINTS BALANCE").font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
                Text("\(customerPoints)").font(.system(size: 32, weight: .heavy)).foregroundColor(.black)
                Spacer()
                Text("Minimum 100 pts for discount").font(.system(size: 10)).foregroundColor(.gray)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 160)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))

            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    Circle().fill(AppColors.rewardIconBg).frame(width: 32, height: 32)
                    Image(systemName: "tag").font(.system(size: 16)).foregroundColor(AppColors.accentOrange)
                }
                Spacer().frame(height: 16)
                Text("REWARD VALUE").font(.system(size: 10, weight: .bold)).foregroundColor(AppColors.accentOrange)
                Text(String(format: "$%.2f", rewardValue)).font(.system(size: 32, weight: .heavy)).foregroundColor(.black)
                Spacer().frame(height: 8)
                RoundedRectangle(cornerRadius: 2).fill(AppColors.darkGreen).frame(width: 60, height: 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 160)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    private var promotionsHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PROMOTIONS & OFFERS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.accentOrange)
                Text("Special Bonus Deals")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
            }
            Spacer()
            Text("Catalog →")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(white: 0.3))
        }
    }

    private var offersGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(offers) { offer in
                Button(action: {
                    viewModel.logOfferClick(offer.title)
                    viewModel.sendNotification("Offer Viewed", "Details for \(offer.title)")
                }) {
                    VStack(spacing: 0) {
                        ZStack {
                            AppColors.lightGreenCard.opacity(0.5)
                            if let imageUrl = offer.imageUrl, let url = URL(string: imageUrl) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: { Color.clear }
                            } else {
                                Image(systemName: "tag")
                                    .font(.system(size: 40))
                                    .foregroundColor(AppColors.primaryGreen)
                            }
                        }
                        .frame(height: 100)
                        .clipped()

                        VStack(alignment: .leading, spacing: 4) {
                            Text(offer.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppColors.darkGreen)
                                .lineLimit(1)
                            Text(offer.price)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppColors.primaryGreen)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
                .frame(height: 180)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
    }
}

// MARK: - ToggleBtn (Kotlin: ToggleBtn composable)

struct ToggleBtn: View {
    let text: String
    let systemImage: String
    let isSelected: Bool
    var isOrange: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage).font(.system(size: 12))
                Text(text).font(.system(size: 10, weight: .bold))
            }
            .foregroundColor((isSelected || isOrange) ? .black : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(
                isOrange ? AppColors.accentOrange
                : (isSelected ? Color.white : Color.white.opacity(0.2))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Catalog tab (Kotlin: CustomerCatalogTab)

struct CustomerCatalogTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @State private var showRedeemDialog = false
    @State private var pointsToRedeem = ""

    private var customer: User? { viewModel.currentUser }
    private var offers: [Offer] { viewModel.offers }
    private var pointSettings: PointSettings? { viewModel.pointSettings }
    private var customerPoints: Int { customer?.points ?? 0 }
    private var discountRate: Double { pointSettings?.discountPer100Points ?? 1.0 }
    private var threshold: Int { pointSettings?.redemptionThreshold ?? 100 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                balanceCard.padding(.bottom, 24)

                Text("Product Catalog")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(AppColors.darkGreen)
                Spacer().frame(height: 16)

                LazyVStack(spacing: 8) {
                    ForEach(offers) { offer in
                        catalogRow(offer)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .alert("Redeem Points", isPresented: $showRedeemDialog) {
            TextField("Points to Redeem", text: $pointsToRedeem)
                .keyboardType(.numberPad)
            Button("Create Voucher") {
                let pts = Int(pointsToRedeem) ?? 0
                if pts >= threshold && pts <= customerPoints {
                    let rewardValue = (Double(pts) / 100.0) * discountRate
                    let reward = Reward(
                        title: "$\(rewardValue) Discount Voucher",
                        description: "Voucher created by user",
                        costInPoints: pts
                    )
                    Task { await viewModel.redeemReward(reward) }
                    pointsToRedeem = ""
                } else {
                    viewModel.sendNotification("Error", "Invalid amount. Minimum is \(threshold) points.")
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have \(customerPoints) points available. Exchange points for a digital voucher you can use at checkout.")
        }
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your Points Balance")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
            Text("\(customerPoints)")
                .font(.system(size: 36, weight: .heavy))
                .foregroundColor(.white)
            Spacer().frame(height: 16)
            Button(action: { showRedeemDialog = true }) {
                Text("Redeem for Voucher")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColors.accentOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(20)
        .background(AppColors.primaryGreen)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func catalogRow(_ offer: Offer) -> some View {
        HStack(spacing: 16) {
            ZStack {
                AppColors.lightGreenCard.opacity(0.5)
                if let imageUrl = offer.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: { Color.clear }
                } else {
                    Image(systemName: "photo")
                        .foregroundColor(AppColors.primaryGreen)
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 4) {
                Text(offer.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.darkGreen)
                Text(offer.category.capitalized)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Spacer().frame(height: 4)
                Text(offer.price)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.primaryGreen)
            }

            Spacer()

            ZStack {
                Circle().fill(AppColors.primaryGreen).frame(width: 36, height: 36)
                Image(systemName: "plus").foregroundColor(.white).font(.system(size: 16, weight: .bold))
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.06), radius: 2)
        .padding(.vertical, 8)
    }
}

// NOTE: the Profile tab is now ProfileView.swift (already in this project —
// it has Get in Touch + Delete Account, which this simpler version didn't),
// wired in above. The old ProfileTab struct that used to live here has been
// removed so there's only one profile screen.

// MARK: - QR tab (Kotlin: CustomerQRTab)

struct CustomerQRTab: View {
    let customer: User?
    @State private var qrImage: UIImage?
    @State private var barcodeImage: UIImage?

    private var email: String { customer?.email ?? "Unknown" }

    var body: some View {
        VStack(spacing: 0) {
            Text("Your Member ID")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppColors.darkGreen)
            Text("Show this at checkout to earn points.")
                .font(.system(size: 14))
                .foregroundColor(.gray)
            Spacer().frame(height: 32)

            VStack {
                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                } else {
                    Color(.systemGray5).aspectRatio(1, contentMode: .fit)
                }
                Spacer().frame(height: 16)
                if let barcodeImage {
                    Image(uiImage: barcodeImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 60)
                } else {
                    Color(.systemGray5).frame(height: 60)
                }
                Spacer().frame(height: 16)
                Text(email)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gray)
                    .tracking(2)
            }
            .padding(24)
            .aspectRatio(0.8, contentMode: .fit)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.1), radius: 8)
        }
        .padding(24)
        .task(id: email) {
            qrImage = CodeGenerator.generateQRCode(from: email, size: 800)
            barcodeImage = CodeGenerator.generateBarcode(from: email, width: 800, height: 200)
        }
    }
}

// MARK: - History tab (Kotlin: CustomerHistoryTab)

struct CustomerHistoryTab: View {
    @ObservedObject var viewModel: LoyaltyViewModel

    private var customer: User? { viewModel.currentUser }
    private var myTransactions: [PointTransaction] {
        viewModel.allTransactions
            .filter { $0.userEmail == customer?.email }
            .sorted { $0.timestamp > $1.timestamp }
    }
    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "MMM dd, yyyy HH:mm"
        return df
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Transaction History")
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(AppColors.darkGreen)
            Spacer().frame(height: 16)

            if myTransactions.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("No recent transactions.").foregroundColor(.gray)
                    Spacer()
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(myTransactions) { tx in
                            historyRow(tx)
                        }
                    }
                }
            }
        }
        .padding(24)
    }

    private func historyRow(_ tx: PointTransaction) -> some View {
        let isCredit = tx.pointChange > 0
        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isCredit ? AppColors.lightGreenCard : AppColors.historyDebitBg)
                    .frame(width: 48, height: 48)
                Image(systemName: isCredit ? "arrow.up" : "arrow.down")
                    .foregroundColor(isCredit ? AppColors.primaryGreen : AppColors.historyDebitTint)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(tx.description)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.darkGreen)
                Text(dateFormatter.string(from: Date(timeIntervalSince1970: tx.timestamp / 1000)))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            Spacer()
            Text("\(isCredit ? "+" : "")\(tx.pointChange)")
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(isCredit ? AppColors.primaryGreen : AppColors.historyDebitTint)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
