import SwiftUI

struct SignUpView: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var fullName = ""
    @State private var email = ""
    @State private var phone = ""

    private let brandGreen = Color(red: 0.30, green: 0.58, blue: 0.24)

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "basket.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 70, height: 70)
                        .foregroundColor(brandGreen)

                    Text("Create Account")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Join & Get 5 Bonus Points")
                        .font(.subheadline)
                        .foregroundColor(brandGreen)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 16) {
                        TextField("Full Name", text: $fullName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        TextField("Email Address", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)

                        TextField("Phone Number (Optional if Email provided)", text: $phone)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.phonePad)

                        Button(action: {
                            viewModel.signup(emailOrPhone: email, phoneOptional: phone, name: fullName)
                        }) {
                            Text("Sign Up")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(brandGreen)
                                .cornerRadius(30)
                        }

                        Button("Already have an account? Log in") {
                            dismiss()
                        }
                        .font(.footnote)
                        .foregroundColor(brandGreen)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .background(Color.white.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
    }
}
