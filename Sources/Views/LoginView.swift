import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    @State private var email = UserDefaults.standard.string(forKey: "saved_email") ?? ""
    @State private var password = UserDefaults.standard.string(forKey: "saved_password") ?? ""
    @State private var rememberMe = UserDefaults.standard.bool(forKey: "remember_me")
    @State private var passwordVisible = false
    
    @FocusState private var isPasswordFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "basket.fill") // Replace with actual logo asset Name in Xcode
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.green)
            
            VStack(spacing: 4) {
                Text("Welcome to")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("Burpengary Market")
                    .font(.title)
                    .fontWeight(.heavy)
                    .foregroundColor(Color(red: 0.1, green: 0.3, blue: 0.1)) // Dark Green
                Text("Your FRESH Shop")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 16) {
                TextField("Username or Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .submitLabel(.next)
                    .onSubmit {
                        isPasswordFieldFocused = true
                    }
                
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
                .background(Color(UIColor.systemBackground))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(UIColor.separator), lineWidth: 1))
                .focused($isPasswordFieldFocused)
                .submitLabel(.done)
                .onSubmit {
                    performLogin()
                }
                
                HStack {
                    Toggle(isOn: $rememberMe) {
                        Text("Remember me")
                            .font(.footnote)
                    }
                    .toggleStyle(CheckboxStyle())
                    
                    Spacer()
                    
                    Button("Forgot Password?") {
                        viewModel.resetPassword(email: email)
                    }
                    .font(.footnote)
                    .foregroundColor(.green)
                }
                
                Button(action: performLogin) {
                    Text("Login")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
        .padding()
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
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isOn ? .green : .gray)
                .onTapGesture { configuration.isOn.toggle() }
            configuration.label
        }
    }
}
