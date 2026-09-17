import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore
import GoogleSignIn
import Combine
import UIKit

class LoyaltyViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var currentUserPoints: Int = 0
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var auditLogs: [AuditLog] = []

    private var db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private var userPointsListener: ListenerRegistration?
    private var auditLogsListener: ListenerRegistration?

    init() {
        Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            guard let self = self else { return }
            if let user = user, let email = user.email {
                self.fetchUserData(email: email)
                self.listenToUserPoints(email: email)
            } else {
                self.currentUser = nil
                self.userPointsListener?.remove()
                self.userPointsListener = nil
                self.auditLogsListener?.remove()
                self.auditLogsListener = nil
                self.auditLogs = []
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

    /// Real-time balance for display. Note: `fetchUserData` below already
    /// decodes the full `User` (including `points`) via its own snapshot
    /// listener, so `currentUser?.points` is already live. This is kept as
    /// a lighter-weight alternative in case a view only wants the number.
    func listenToUserPoints(email: String) {
        userPointsListener?.remove()
        userPointsListener = db.collection("users").document(email)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let data = snapshot?.data() else { return }
                self?.currentUserPoints = data["points"] as? Int ?? 0
            }
    }

    /// Live feed of the audit trail for SuperAdminView. Firestore security
    /// rules — not this client-side call — should be what actually restricts
    /// who can read this collection; call this once you know the signed-in
    /// user is staff, to avoid an unused listener for customer accounts.
    func listenToAuditLogs() {
        auditLogsListener?.remove()
        auditLogsListener = db.collection("auditLogs")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching audit logs: \(error)")
                    return
                }
                guard let docs = snapshot?.documents else { return }
                self?.auditLogs = docs.compactMap { try? $0.data(as: AuditLog.self) }
            }
    }

    private func logAudit(action: String, changedBy: String) {
        let entry: [String: Any] = [
            "action": action,
            "changedBy": changedBy,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        db.collection("auditLogs").addDocument(data: entry)
    }

    /// Atomic, race-safe redemption. Reads and writes the balance inside a
    /// single Firestore transaction, so two devices (or a device + a
    /// register) redeeming the same account at the same moment can't both
    /// succeed against a balance that only supports one of them. Firestore
    /// automatically retries the transaction if it detects a conflicting
    /// write, so this stays correct even under real concurrent access.
    func redeemPoints(email: String, amount: Int, changedBy: String, completion: @escaping (Bool, String?) -> Void) {
        let userRef = db.collection("users").document(email)

        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(userRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            let currentPoints = snapshot.data()?["points"] as? Int ?? 0
            guard currentPoints >= amount else {
                errorPointer?.pointee = NSError(
                    domain: "Redemption", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Insufficient points"]
                )
                return nil
            }

            transaction.updateData(["points": currentPoints - amount], forDocument: userRef)
            return nil
        }) { [weak self] _, error in
            if error == nil {
                self?.logAudit(action: "Redeemed \(amount) points for \(email)", changedBy: changedBy)
            }
            completion(error == nil, error?.localizedDescription)
        }
    }

    /// Atomic add. FieldValue.increment is applied server-side by Firestore,
    /// so this is safe under concurrent writes (two cashiers, two devices)
    /// without needing a full transaction.
    func addPoints(email: String, amount: Int, changedBy: String, completion: ((Bool, String?) -> Void)? = nil) {
        let userRef = db.collection("users").document(email)
        userRef.updateData(["points": FieldValue.increment(Int64(amount))]) { [weak self] error in
            if error == nil {
                self?.logAudit(action: "Added \(amount) points to \(email)", changedBy: changedBy)
            }
            completion?(error == nil, error?.localizedDescription)
        }
    }

    /// Synchronous local search over the already-loaded customer list, for
    /// CashierView's "find a customer" flow. Assumes `allCustomers`
    /// ([User], populated by whatever listener already backs
    /// AdminCustomersTab) exists elsewhere in this class - it isn't in this
    /// file as uploaded, so add this method next to wherever that property
    /// is actually declared, not here, if this snippet was trimmed.
    func searchUsers(_ query: String) -> [User] {
        guard !query.isEmpty else { return allCustomers }
        return allCustomers.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.email.localizedCaseInsensitiveContains(query)
        }
    }

    /// Cashier flow: award points for a dollar purchase amount, using the
    /// current pointsPerDollar rate from `pointSettings`. Reuses the
    /// existing `addPoints` transaction/audit path above rather than
    /// writing to Firestore directly.
    func processPurchase(customerEmail: String, amount: Double, completion: ((Bool, String?) -> Void)? = nil) {
        errorMessage = nil
        successMessage = nil
        guard amount > 0 else {
            errorMessage = "Enter a valid purchase amount"
            completion?(false, errorMessage)
            return
        }
        let rate = pointSettings?.pointsPerDollar ?? 10
        let pointsEarned = Int((amount * Double(rate)).rounded())
        let staffEmail = currentUser?.email ?? "cashier"

        addPoints(email: customerEmail, amount: pointsEarned, changedBy: staffEmail) { [weak self] success, error in
            if success {
                self?.successMessage = "Awarded \(pointsEarned) points to \(customerEmail)"
            } else {
                self?.errorMessage = error
            }
            completion?(success, error)
        }
    }

    func logout() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            self.currentUser = nil
            self.userPointsListener?.remove()
            self.userPointsListener = nil
            self.auditLogsListener?.remove()
            self.auditLogsListener = nil
            self.auditLogs = []
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
