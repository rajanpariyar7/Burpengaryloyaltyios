import SwiftUI

struct SignupView: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var confirmPassword = ""

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
                secureField("Password (min 6 characters)", text: $password)
                secureField("Confirm password", text: $confirmPassword)

                Button("Sign Up") {
                    guard password == confirmPassword else {
                        viewModel.notify("Error", "Passwords do not match.")
                        return
                    }
                    viewModel.signup(email: email, password: password, name: name, phone: phone)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(name.isEmpty || email.isEmpty || password.count < 6)

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

    private func secureField(_ placeholder: String, text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.borderSlate))
    }
}
