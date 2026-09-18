import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @State private var showGetInTouch = false
    @State private var showDeleteAlert = false
    @State private var showPasswordAlert = false
    @State private var newPassword = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0xF3/255.0, green: 0xF4/255.0, blue: 0xF1/255.0)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        Spacer().frame(height: 10)

                        // Avatar Circle
                        ZStack {
                            Circle()
                                .fill(Color(red: 0xD5/255.0, green: 0xE8/255.0, blue: 0xD4/255.0))
                                .frame(width: 84, height: 84)
                            Text(String(viewModel.currentUser?.name.prefix(1) ?? "C").uppercased())
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(AppColors.primaryGreen)
                        }

                        VStack(spacing: 4) {
                            Text(viewModel.currentUser?.name ?? "Customer")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(AppColors.darkGreen)

                            Text(viewModel.currentUser?.email ?? "guest@burpengarymarket.com.au")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }

                        // Points & Stamps Chip
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .foregroundColor(AppColors.primaryGreen)
                                .font(.system(size: 14))
                            Text("\(viewModel.currentUser?.points ?? 0) Points • \(viewModel.currentUser?.stamps ?? 0)/10 Stamps")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppColors.darkGreen)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(AppColors.primaryGreen.opacity(0.3), lineWidth: 1)
                        )

                        // GET IN TOUCH CARD
                        VStack(alignment: .leading, spacing: 14) {
                            Button(action: { showGetInTouch = true }) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(red: 0xE8/255.0, green: 0xF5/255.0, blue: 0xE9/255.0))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "storefront.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(AppColors.primaryGreen)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Get in Touch")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(AppColors.darkGreen)
                                        Text("Shop 17, 179 Station Rd, Burpengary Plaza")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.gray)
                                }
                            }

                            Divider()

                            // Quick contact buttons
                            HStack(spacing: 10) {
                                QuickLinkButton(
                                    icon: "mappin.and.ellipse",
                                    title: "Map",
                                    color: AppColors.primaryGreen,
                                    url: "https://maps.google.com/?q=Burpengary+Fruit+Market,+179+Station+Rd,+Burpengary+QLD+4505"
                                )

                                QuickLinkButton(
                                    icon: "phone.fill",
                                    title: "Call",
                                    color: AppColors.darkGreen,
                                    url: "tel:+61430430484"
                                )

                                QuickLinkButton(
                                    icon: "message.fill",
                                    title: "WhatsApp",
                                    color: Color(red: 0x25/255.0, green: 0xD3/255.0, blue: 0x66/255.0),
                                    url: "https://wa.me/61430430484"
                                )

                                QuickLinkButton(
                                    icon: "globe",
                                    title: "Facebook",
                                    color: Color(red: 0x18/255.0, green: 0x77/255.0, blue: 0xF2/255.0),
                                    url: "https://www.facebook.com/BurpengaryFruitMarket"
                                )
                            }

                            Button(action: { showGetInTouch = true }) {
                                Text("View Store Hours & Full Contact Details →")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(AppColors.primaryGreen)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)

                        // Sign Out Button
                        Button(action: { viewModel.signOut() }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                                    .fontWeight(.bold)
                            }
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppColors.primaryGreen)
                            .cornerRadius(14)
                        }

                        // Delete Account (Apple Guideline 5.1.1(v))
                        Button(action: { showDeleteAlert = true }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Account")
                                    .fontWeight(.semibold)
                            }
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                        }
                        .padding(.top, 4)

                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showGetInTouch) {
                GetInTouchView()
            }
            .alert(isPresented: $showDeleteAlert) {
                Alert(
                    title: Text("Delete Account"),
                    message: Text("Are you sure you want to permanently delete your account and all associated loyalty points and stamps? This cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        viewModel.deleteAccount { _ in }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}

struct QuickLinkButton: View {
    let icon: String
    let title: String
    let color: Color
    let url: String

    var body: some View {
        Link(destination: URL(string: url)!) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.darkGreen)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(red: 0xF3/255.0, green: 0xF4/255.0, blue: 0xF1/255.0))
            .cornerRadius(12)
        }
    }
}
