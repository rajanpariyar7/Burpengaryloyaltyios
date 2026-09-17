import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @State private var email = UserDefaults.standard.string(forKey: "saved_email") ?? ""
    @State private var password = UserDefaults.standard.string(forKey: "saved_password") ?? ""
    @State private var rememberMe = UserDefaults.standard.bool(forKey: "remember_me")
    @State private var passwordVisible = false
    @State private var showSignUp = false

    @FocusState private var isPasswordFieldFocused: Bool

    // Match the Android app's brand green instead of system default green
    private let brandGreen = Color(red: 0.30, green: 0.58, blue: 0.24)
    private let darkGreenText = Color(red: 0.1, green: 0.3, blue: 0.1)

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "basket.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(brandGreen)

                    VStack(spacing: 4) {
                        Text("Welcome to")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text("Burpengary Market")
                            .font(.title)
                            .fontWeight(.heavy)
                            .foregroundColor(darkGreenText)
                        Text("Your FRESH Shop")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(brandGreen)
                    }

                    // Error / success banners so failed logins are actually visible
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    if let success = viewModel.successMessage {
                        Text(success)
                            .font(.footnote)
                            .foregroundColor(brandGreen)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    VStack(spacing: 16) {
                        TextField("Username or Email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .submitLabel(.next)
                            .onSubmit { isPasswordFieldFocused = true }

                        HStack {
                            if passwordVisible {
                                TextField("Password", text: $password)
                            } else {
                                SecureField("Password", text: $password)
                            }
                            Button(action: { passwordVisible.toggle() }) {
                                Image(systemName: passwordVisible ? "eye.fill" : "eye.slash.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(UIColor.separator), lineWidth: 1))
                        .focused($isPasswordFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { performLogin() }

                        HStack {
                            Toggle(isOn: $rememberMe) {
                                Text("Remember me").font(.footnote)
                            }
                            .toggleStyle(CheckboxStyle(tint: brandGreen))

                            Spacer()

                            Button("Forgot Password?") {
                                viewModel.resetPassword(email: email)
                            }
                            .font(.footnote)
                            .foregroundColor(brandGreen)
                        }

                        Button(action: performLogin) {
                            Text("Login")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(brandGreen)
                                .cornerRadius(30)
                        }

                        Button(action: { viewModel.signInWithGoogle() }) {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                Text("Sign in with Google")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(30)
                            .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color(UIColor.separator), lineWidth: 1))
                        }

                        Button(action: { showSignUp = true }) {
                            Text("Don't have an account? Sign up")
                                .font(.footnote)
                                .foregroundColor(brandGreen)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .background(Color.white.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showSignUp) {
                SignUpView(viewModel: viewModel)
            }
        }
        .navigationViewStyle(.stack)
        // Force light appearance so this screen matches the Android app
        // regardless of the device's system Dark Mode setting.
        .preferredColorScheme(.light)
    }

    private func performLogin() {
        if rememberMe {
            UserDefaults.standard.set(email, forKey: "saved_email")
            UserDefaults.standard.set(password, forKey: "saved_password")
            UserDefaults.standard.set(true, forKey: "remember_me")
        } else {
            UserDefaults.standard.removeObject(forKey: "saved_email")
            UserDefaults.standard.removeObject(forKey: "saved_password")
            UserDefaults.standard.set(false, forKey: "remember_me")
        }
        viewModel.login(email: email, pass: password)
    }
}

struct CheckboxStyle: ToggleStyle {
    var tint: Color = .green
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isOn ? tint : .gray)
                .onTapGesture { configuration.isOn.toggle() }
            configuration.label
        }
    }
}
