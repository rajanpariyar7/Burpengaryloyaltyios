import SwiftUI
import UIKit

struct LoginView: View {
    @ObservedObject var viewModel: LoyaltyViewModel

    @AppStorage("rememberedEmail") private var rememberedEmail = ""
    @State private var email = ""
    @State private var password = ""
    @State private var rememberMe = false
    @State private var showPassword = false
    @State private var showSignup = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header

                    VStack(spacing: 14) {
                        TextField("Email or Username", text: $email)
                            .textContentType(.username)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.borderSlate))

                        HStack {
                            Group {
                                if showPassword {
                                    TextField("Password", text: $password)
                                } else {
                                    SecureField("Password", text: $password)
                                }
                            }
                            .textContentType(.password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.borderSlate))

                        HStack {
                            Toggle("Remember me", isOn: $rememberMe)
                                .toggleStyle(.switch)
                                .tint(Palette.primaryGreen)
                                .font(.subheadline)
                            Spacer()
                            Button("Forgot password?") {
                                viewModel.resetPassword(email: email)
                            }
                            .font(.subheadline)
                            .foregroundColor(Palette.primaryGreen)
                        }
                    }

                    Button("Log In") {
                        rememberedEmail = rememberMe ? email : ""
                        viewModel.login(email: email, password: password)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    HStack {
                        Rectangle().fill(Palette.borderSlate).frame(height: 1)
                        Text("OR").font(.caption).foregroundColor(.gray)
                        Rectangle().fill(Palette.borderSlate).frame(height: 1)
                    }

                    Button {
                        if let controller = UIApplication.shared.topViewController {
                            viewModel.signInWithGoogle(presenting: controller)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "g.circle.fill")
                            Text("Continue with Google").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundColor(Palette.extraDarkGreen)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.borderSlate))
                    }

                    Button("New here? Create a membership") {
                        showSignup = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Palette.primaryGreen)
                }
                .padding(24)
            }
            .background(Palette.backgroundLight.ignoresSafeArea())
            .navigationDestination(isPresented: $showSignup) {
                SignupView(viewModel: viewModel)
            }
        }
        .onAppear {
            if !rememberedEmail.isEmpty {
                email = rememberedEmail
                rememberMe = true
            }
        }
        .notificationAlert(viewModel)
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Palette.lightGreenCard).frame(width: 96, height: 96)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Palette.primaryGreen)
            }
            Text("Burpengary Market")
                .font(.largeTitle.weight(.heavy))
                .foregroundColor(Palette.extraDarkGreen)
            Text("Loyalty & Rewards")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.bottom, 12)
    }
}

extension UIApplication {
    var topViewController: UIViewController? {
        let scene = connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var controller = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}
