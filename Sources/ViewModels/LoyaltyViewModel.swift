import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore
import GoogleSignIn
import Combine
import UIKit

class LoyaltyViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var errorMessage: String?
    @Published var successMessage: String?
    private var db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()

    init() {
        Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            guard let self = self else { return }
            if let user = user, let email = user.email {
                self.fetchUserData(email: email)
            } else {
                self.currentUser = nil
            }
        }
    }

    func login(email: String, pass: String) {
        errorMessage = nil
        successMessage = nil
        guard !email.isEmpty, !pass.isEmpty else {
            self.errorMessage = "Email and Password required"
            return
        }

        Auth.auth().signIn(withEmail: email, password: pass) { [weak self] result, error in
            if let error = error {
                // Firebase requires a real email address here. If the Android
                // app allows "username" login, that has to be resolved to an
                // email server-side (e.g. a Firestore lookup) before calling
                // signIn(withEmail:) - a bare username will always fail here.
                self?.errorMessage = error.localizedDescription
                return
            }
            self?.successMessage = "Logged in successfully"
        }
    }

    /// Presents the Google Sign-In flow and signs the resulting credential
    /// into Firebase Auth. Requires GoogleService-Info.plist's CLIENT_ID and
    /// the matching CFBundleURLSchemes entry (already present in project.yml).
    func signInWithGoogle() {
        errorMessage = nil
        successMessage = nil

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            self.errorMessage = "Google Sign-In is not configured."
            return
        }

        guard let presentingVC = Self.topViewController() else {
            self.errorMessage = "Unable to present Google Sign-In."
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC) { [weak self] result, error in
            guard let self = self else { return }
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                self.errorMessage = "Google Sign-In failed to return a token."
                return
            }

            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                             accessToken: user.accessToken.tokenString)

            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                guard let self = self else { return }
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                guard let email = authResult?.user.email else {
                    self.errorMessage = "Google account has no email."
                    return
                }
                // First-time Google sign-in: create the Firestore user doc
                // (mirrors Android's Google sign-in bootstrap) if missing.
                self.db.collection("users").document(email).getDocument { [weak self] snapshot, _ in
                    guard let self = self else { return }
                    if snapshot?.exists != true {
                        let newUser = User(
                            email: email,
                            name: authResult?.user.displayName ?? "",
                            role: .customer,
                            points: 5
                        )
                        try? self.db.collection("users").document(email).setData(from: newUser)
                    }
                }
            }
        }
    }

    func signup(emailOrPhone: String, phoneOptional: String, name: String) {
        errorMessage = nil
        successMessage = nil
        let identifier = emailOrPhone.isEmpty ? phoneOptional : emailOrPhone
        guard !identifier.isEmpty else {
            self.errorMessage = "Email or Phone required"
            return
        }

        let defaultPassword = String(identifier.prefix(4)) + "1234"

        Auth.auth().createUser(withEmail: identifier, password: defaultPassword) { [weak self] result, error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
                return
            }

            let newUser = User(
                email: identifier,
                passwordHash: defaultPassword,
                name: name,
                role: .customer,
                points: 5 // Bonus points!
            )

            do {
                try self?.db.collection("users").document(identifier).setData(from: newUser)
                self?.successMessage = "Account created! 5 bonus points awarded."
            } catch {
                self?.errorMessage = "Failed to save user data."
            }
        }
    }

    func resetPassword(email: String) {
        errorMessage = nil
        successMessage = nil
        guard !email.isEmpty else {
            self.errorMessage = "Please enter your email to reset password"
            return
        }
        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
            } else {
                self?.successMessage = "Password reset email sent"
            }
        }
    }
func listenToUserPoints(email: String) {
    Firestore.firestore().collection("users").document(email)
        .addSnapshotListener { [weak self] snapshot, _ in
            guard let data = snapshot?.data() else { return }
            self?.currentUserPoints = data["points"] as? Int ?? 0
         }
    }
    func logout() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            self.currentUser = nil
        } catch {
            self.errorMessage = "Failed to logout"
        }
    }

    private func fetchUserData(email: String) {
        db.collection("users").document(email).addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                print("Error fetching user: \(error)")
                return
            }
            do {
                self?.currentUser = try snapshot?.data(as: User.self)
            } catch {
                print("Error decoding user: \(error)")
            }
        }
    }

    private static func topViewController(_ base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
        .first?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(nav.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(selected)
        }
        if let presented = base?.presentedViewController {
            return topViewController(presented)
        }
        return base
    }
}
