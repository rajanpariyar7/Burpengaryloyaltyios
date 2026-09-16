import SwiftUI

struct MembershipCardView: View {
    let user: User
    @State private var showBarcode = false

    var memberCode: String { user.customerId.isEmpty ? user.email : user.customerId }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MEMBER")
                        .font(.caption2.weight(.bold))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.7))
                    Text(user.name.isEmpty ? "Valued Customer" : user.name)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                    Text(memberCode)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("\(user.points)")
                        .font(.title2.weight(.heavy))
                        .foregroundColor(Palette.extraDarkGreen)
                    Text("POINTS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Palette.extraDarkGreen)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Palette.accentOrange)
                .clipShape(Capsule())
            }

            VStack(spacing: 10) {
                if showBarcode {
                    BarcodeView(value: memberCode, height: 80)
                } else {
                    QRCodeView(value: memberCode, size: 150)
                }
                Text("Show this at the register to earn or redeem points")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Picker("Code type", selection: $showBarcode) {
                Text("QR Code").tag(false)
                Text("Barcode").tag(true)
            }
            .pickerStyle(.segmented)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Palette.forestGreen, Palette.primaryGreen],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
