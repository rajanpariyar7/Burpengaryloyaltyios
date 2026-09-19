import SwiftUI
import GoogleSignIn
import FirebaseAuth

// MARK: - Color Palette matching Android Theme.kt exactly
struct AppColors {
    static let primaryGreen = Color(red: 0x5A/255.0, green: 0x8F/255.0, blue: 0x3A/255.0)
    static let darkGreen = Color(red: 0x1A/255.0, green: 0x24/255.0, blue: 0x1B/255.0)
    static let backgroundLight = Color(red: 0xFD/255.0, green: 0xFB/255.0, blue: 0xF7/255.0)
    static let borderSlate = Color(red: 0xE8/255.0, green: 0xEB/255.0, blue: 0xE8/255.0)
}

struct LoginView: View {
    @ObservedObject var viewModel: LoyaltyViewModel
    
    @State private var email = UserDefaults.standard.string(forKey: "saved_email") ?? ""
    @State private var password = UserDefaults.standard.string(forKey: "saved_password") ?? ""
    @State private var rememberMe = UserDefaults.standard.bool(forKey: "remember_me")
    @State private var passwordVisible = false
    @State private var isSignupMode = false
    
    // Forgot Password Alert State
    @State private var showForgotPasswordAlert = false
    @State private var forgotPasswordEmail = ""
    
    // Status message alert
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    @FocusState private var isPasswordFieldFocused: Bool
    
    var body: some View {
        ZStack {
            AppColors.backgroundLight
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    if !isSignupMode {
                        loginContent
                    } else {
                        signupContent
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert("Reset Password", isPresented: $showForgotPasswordAlert) {
            TextField("Email Address", text: $forgotPasswordEmail)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
            Button("Send Reset Link") {
                viewModel.resetPassword(email: forgotPasswordEmail)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter your email address to receive a password reset link:")
        }
        .onChange(of: viewModel.errorMessage) { newError in
            if let error = newError {
                alertTitle = "Error"
                alertMessage = error
                showAlert = true
                viewModel.errorMessage = nil
            }
        }
        .onChange(of: viewModel.successMessage) { newSuccess in
            if let success = newSuccess {
                alertTitle = "Success"
                alertMessage = success
                showAlert = true
                viewModel.successMessage = nil
            }
        }
    }
    
    // MARK: - Login Screen (Matches Android LoginScreen)
    private var loginContent: some View {
        VStack(spacing: 20) {
            // App Logo
            Image(systemName: "basket.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(AppColors.primaryGreen)
                .padding(.bottom, 8)
            
            // Header Typography
            VStack(spacing: 4) {
                Text("Welcome to")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                Text("Burpengary Market")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(AppColors.darkGreen)
                Text("Your FRESH Shop")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.primaryGreen)
            }
            .padding(.bottom, 12)
            
            // Username / Email Field
            VStack(alignment: .leading, spacing: 6) {
                Text("Username or Email")
                    .font(.caption)
                    .foregroundColor(.gray)
                TextField("Enter email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                    .submitLabel(.next)
                    .onSubmit { isPasswordFieldFocused = true }
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: 6) {
                Text("Password")
                    .font(.caption)
                    .foregroundColor(.gray)
                HStack {
                    if passwordVisible {
                        TextField("Enter password", text: $password)
                    } else {
                        SecureField("Enter password", text: $password)
                    }
                    Button(action: { passwordVisible.toggle() }) {
                        Image(systemName: passwordVisible ? "eye.fill" : "eye.slash.fill")
                            .foregroundColor(.gray)
                    }
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                .focused($isPasswordFieldFocused)
                .submitLabel(.done)
                .onSubmit { performLogin() }
            }
            
            // Remember Me & Forgot Password Row
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                        .foregroundColor(rememberMe ? AppColors.primaryGreen : .gray)
                        .font(.system(size: 20))
                        .onTapGesture { rememberMe.toggle() }
                    Text("Remember me")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button(action: {
                    forgotPasswordEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                    showForgotPasswordAlert = true
                }) {
                    Text("Forgot Password?")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.primaryGreen)
                }
            }
            .padding(.vertical, 4)
            
            // Login Button (Height 56pt, matches Android)
            Button(action: performLogin) {
                Text("Login")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppColors.primaryGreen)
                    .cornerRadius(12)
            }
            
            // Google Sign-In Button (Height 56pt, matches Android OutlinedButton)
            Button(action: performGoogleSignIn) {
                HStack(spacing: 12) {
                    Image(systemName: "g.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.red)
                    Text("Sign in with Google")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.4), lineWidth: 1))
            }
            
            // Switch to Signup
            Button(action: { isSignupMode = true }) {
                Text("Don't have an account? Sign up")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.primaryGreen)
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - Signup Screen (Matches Android SignupScreen)
    @State private var signupName = ""
    @State private var signupEmail = ""
    @State private var signupPhone = ""
    
    private var signupContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "basket.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(AppColors.primaryGreen)
                .padding(.bottom, 8)
            
            VStack(spacing: 4) {
                Text("Create Account")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(AppColors.darkGreen)
                Text("Join & Get 5 Bonus Points")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.primaryGreen)
            }
            .padding(.bottom, 12)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Full Name")
                    .font(.caption)
                    .foregroundColor(.gray)
                TextField("Full Name", text: $signupName)
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4), lineWidth: 1))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Email Address")
                    .font(.caption)
                    .foregroundColor(.gray)
                TextField("Email Address", text: $signupEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4), lineWidth: 1))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Phone Number (Optional if Email provided)")
                    .font(.caption)
                    .foregroundColor(.gray)
                TextField("Phone Number", text: $signupPhone)
                    .keyboardType(.phonePad)
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4), lineWidth: 1))
            }
            
            Button(action: {
                viewModel.signup(emailOrPhone: signupEmail, phoneOptional: signupPhone, name: signupName)
            }) {
                Text("Sign Up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppColors.primaryGreen)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
            
            Button(action: { isSignupMode = false }) {
                Text("Already have an account? Log in")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.primaryGreen)
            }
        }
    }
    
    // MARK: - Actions
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
    
    private func performGoogleSignIn() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            viewModel.errorMessage = "Unable to launch Google Sign-In"
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { signInResult, error in
            if let error = error {
                viewModel.errorMessage = error.localizedDescription
                return
            }
            guard let user = signInResult?.user,
                  let idToken = user.idToken?.tokenString else {
                viewModel.errorMessage = "Failed to retrieve Google token"
                return
            }
            let accessToken = user.accessToken.tokenString
            viewModel.loginWithGoogle(idToken: idToken, accessToken: accessToken)
        }
    }
}
