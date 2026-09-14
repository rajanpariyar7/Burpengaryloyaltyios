import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var isSignUpMode = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                VStack(spacing: 4) {
                    Text("Burpengary Fruit Market")
                        .font(.title2).bold()
                    Text("Loyalty & Rewards")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    if isSignUpMode {
                        TextField("Full name", text: $name)
                            .textContentType(.name)
                            .textFieldStyle(.roundedBorder)
                    }

                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $password)
                        .textContentType(isSignUpMode ? .newPassword : .password)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    Task {
                        if isSignUpMode {
                            await authViewModel.signUp(name: name, email: email, password: password)
                        } else {
                            await authViewModel.signIn(email: email, password: password)
                        }
                    }
                } label: {
                    if authViewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(isSignUpMode ? "Create account" : "Sign in")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .disabled(email.isEmpty || password.isEmpty || authViewModel.isLoading)

                Button(isSignUpMode ? "Already have an account? Sign in" : "New here? Create an account") {
                    isSignUpMode.toggle()
                }
                .font(.footnote)

                HStack {
                    VStack { Divider() }
                    Text("or").font(.caption).foregroundStyle(.secondary)
                    VStack { Divider() }
                }
                .padding(.horizontal)

                Button {
                    Task { await authViewModel.signInWithGoogle() }
                } label: {
                    HStack {
                        Image(systemName: "g.circle.fill")
                        Text("Sign in with Google")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .disabled(authViewModel.isLoading)

                Spacer()
                Spacer()
            }
        }
    }
}
