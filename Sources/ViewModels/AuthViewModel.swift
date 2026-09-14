import Foundation
import FirebaseAuth

@MainActor
final class AuthViewModel: ObservableObject {

    @Published var isAuthenticated = false
    @Published var currentUser: AppUser?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self else { return }
            Task {
                if firebaseUser?.email != nil {
                    await self.loadProfile()
                } else {
                    self.isAuthenticated = false
                    self.currentUser = nil
                }
            }
        }
    }

    deinit {
        if let authHandle { Auth.auth().removeStateDidChangeListener(authHandle) }
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await AuthService.shared.signIn(email: email, password: password)
            // Matches Android: if Firebase Auth succeeds but there's no
            // Firestore profile yet, create a default CUSTOMER doc.
            if try await FirestoreService.shared.lookupUser(email: email) == nil {
                try await FirestoreService.shared.createUser(
                    AppUser(email: email, name: String(email.split(separator: "@").first ?? ""), role: .customer)
                )
            }
            await loadProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Matches Android's `loginWithGoogle`: sign in with Google, then create
    /// a CUSTOMER Firestore doc with a 5-point bonus if this is a new user.
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        do {
            let firebaseUser = try await AuthService.shared.signInWithGoogle()
            guard let email = firebaseUser.email else { throw AuthError.notAuthenticated }

            if try await FirestoreService.shared.lookupUser(email: email) == nil {
                let name = firebaseUser.displayName ?? String(email.split(separator: "@").first ?? "")
                try await FirestoreService.shared.createUser(
                    AppUser(email: email, name: name, role: .customer, points: 5)
                )
            }
            await loadProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Matches Android's signup: creates the Firebase Auth account, then a
    /// CUSTOMER Firestore doc keyed by email with a 5-point signup bonus.
    func signUp(name: String, email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await AuthService.shared.signUp(name: name, email: email, password: password)
            try await FirestoreService.shared.createUser(
                AppUser(email: email, name: name, role: .customer, points: 5)
            )
            await loadProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() {
        do {
            try AuthService.shared.signOut()
            isAuthenticated = false
            currentUser = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// New: cashiers can be locked out by the admin (kill switch) or
    /// restricted to a login time window (e.g. store hours). Admins and
    /// Super Admins are never gated — only CASHIER accounts.
    private func loadProfile() async {
        do {
            let profile = try await FirestoreService.shared.fetchProfile()

            if profile.role == .cashier {
                let settings = try await FirestoreService.shared.fetchSettings()

                guard settings.cashierLoginEnabled else {
                    try? AuthService.shared.signOut()
                    currentUser = nil
                    isAuthenticated = false
                    errorMessage = "Cashier login is currently disabled by the admin."
                    return
                }

                guard settings.isWithinCashierLoginWindow() else {
                    try? AuthService.shared.signOut()
                    currentUser = nil
                    isAuthenticated = false
                    errorMessage = "Cashier login is only allowed between \(settings.cashierLoginStartTime) and \(settings.cashierLoginEndTime)."
                    return
                }
            }

            currentUser = profile
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
            isAuthenticated = false
        }
    }
}
