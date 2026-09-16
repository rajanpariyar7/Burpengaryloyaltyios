import SwiftUI

struct SignupView: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                SectionHeader(
                    title: "Create your membership",
                    subtitle: "Join the Burpengary Market loyalty program and start earning points today."
                )

                field("Full Name", text: $name)
                field("Email", text: $email, keyboard: .emailAddress)
                field("Phone (optional)", text: $phone, keyboard: .phonePad)

                Button("Sign Up") {
                    viewModel.signup(emailOrPhone: email, phone: phone, name: name)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Already a member? Log in") { dismiss() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Palette.primaryGreen)
            }
            .padding(24)
        }
        .background(Palette.backgroundLight.ignoresSafeArea())
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
        .notificationAlert(viewModel)
    }

    private func field(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
            .autocorrectionDisabled()
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.borderSlate))
    }
}
