import SwiftUI

struct CardContainer<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.borderSlate))
    }
}

struct StatCard: View {
    let value: String
    let label: String
    var tint: Color = Palette.primaryGreen

    var body: some View {
        CardContainer {
            VStack(spacing: 6) {
                Text(value)
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundColor(tint)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundColor(Palette.extraDarkGreen)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TransactionRow: View {
    let transaction: PointTransaction
    var showCustomer: Bool = false

    private var isPositive: Bool { transaction.pointChange > 0 }

    var body: some View {
        CardContainer(padding: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isPositive ? Palette.lightGreenCard : Palette.negativeTint)
                        .frame(width: 40, height: 40)
                    Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                        .foregroundColor(isPositive ? Palette.primaryGreen : Palette.negativeRed)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(transaction.description)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Palette.darkGreen)
                    if showCustomer {
                        Text("Customer: \(transaction.userEmail)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(isPositive ? "+" : "")\(transaction.pointChange)")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(isPositive ? Palette.primaryGreen : Palette.negativeRed)
                    Text(transaction.date, format: .dateTime.day().month().year().hour().minute())
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var background: Color = Palette.primaryGreen

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(background.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.borderSlate))
    }
}

/// Presents view-model notifications as alerts, so every Android toast/snackbar has an
/// on-screen equivalent.
struct NotificationAlert: ViewModifier {
    @ObservedObject var viewModel: LoyaltyViewModel

    func body(content: Content) -> some View {
        content.alert(
            viewModel.notification?.title ?? "",
            isPresented: Binding(
                get: { viewModel.notification != nil },
                set: { if !$0 { viewModel.notification = nil } }
            ),
            presenting: viewModel.notification
        ) { _ in
            Button("OK", role: .cancel) { viewModel.notification = nil }
        } message: { notification in
            Text(notification.message)
        }
    }
}

extension View {
    func notificationAlert(_ viewModel: LoyaltyViewModel) -> some View {
        modifier(NotificationAlert(viewModel: viewModel))
    }
}
