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

    // Public catalog data - readable by any signed-in user per firestore.rules,
    // so these listeners start in init() rather than being gated behind a role check.
    @Published var offers: [Offer] = []
    @Published var categories: [Category] = []
    @Published var pointSettings: PointSettings?

    // Staff-only data. NOT started automatically - call listenToAdminData()
    // once you know the signed-in user is ADMIN/SUPER_ADMIN. Firestore
    // security rules, not this client-side gate, are what actually enforce
    // who can read this data; this just avoids opening unused listeners for
    // customer/cashier accounts.
    @Published var allUsers: [User] = []
    @Published var allTransactions: [PointTransaction] = []

    /// Derived from `allUsers` rather than a separate listener/collection -
    /// one less live query to keep in sync.
    var allCustomers: [User] { allUsers.filter { $0.role == .customer } }

    private var db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()

    private var userPointsListener: ListenerRegistration?
    private var auditLogsListener: ListenerRegistration?
    private var offersListener: ListenerRegistration?
    private var categoriesListener: ListenerRegistration?
    private var pointSettingsListener: ListenerRegistration?
    private var allUsersListener: ListenerRegistration?
    private var allTransactionsListener: ListenerRegistration?

    init() {
        listenToPublicCatalogData()

        Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            guard let self = self else { return }
            if let user = user, let email = user.email {
                self.fetchUserData(email: email)
                self.listenToUserPoints(email: email)
            } else {
                self.clearUserScopedState()
            }
        }
    }

    private func clearUserScopedState() {
        currentUser = nil
        currentUserPoints = 0

        userPointsListener?.remove()
        userPointsListener = nil

        auditLogsListener?.remove()
        auditLogsListener = nil
        auditLogs = []

        allUsersListener?.remove()
        allUsersListener = nil
        allUsers = []

        allTransactionsListener?.remove()
        allTransactionsListener = nil
        allTransactions = []
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

    /// Public catalog data (offers, categories, global point settings).
    /// Started unconditionally in init() - see the property comments above
    /// for why this is treated differently from the staff-only listeners.
    private func listenToPublicCatalogData() {
        offersListener = db.collection("offers").addSnapshotListener { [weak self] snapshot, error in
            guard let docs = snapshot?.documents else { return }
            self?.offers = docs.compactMap { try? $0.data(as: Offer.self) }
        }

        categoriesListener = db.collection("categories").addSnapshotListener { [weak self] snapshot, error in
            guard let docs = snapshot?.documents else { return }
            self?.categories = docs.compactMap { try? $0.data(as: Category.self) }
        }

        pointSettingsListener = db.collection("settings").document("main")
            .addSnapshotListener { [weak self] snapshot, error in
                self?.pointSettings = try? snapshot?.data(as: PointSettings.self)
            }
    }

    /// Staff-only data (all users, the full transaction ledger, audit log).
    /// Call this explicitly - e.g. from AdminView/SuperAdminView's
    /// `.onAppear` - once you know the signed-in user is ADMIN/SUPER_ADMIN.
    func listenToAdminData() {
        listenToAuditLogs()

        allUsersListener?.remove()
        allUsersListener = db.collection("users").addSnapshotListener { [weak self] snapshot, error in
            guard let docs = snapshot?.documents else { return }
            self?.allUsers = docs.compactMap { try? $0.data(as: User.self) }
        }

        allTransactionsListener?.remove()
        allTransactionsListener = db.collection("transactions")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let docs = snapshot?.documents else { return }
                self?.allTransactions = docs.compactMap { try? $0.data(as: PointTransaction.self) }
            }
    }

    /// Live feed of the audit trail for SuperAdminView. Also called by
    /// listenToAdminData() - exposed separately in case a view only wants
    /// this one feed.
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

    private func insertTransaction(userEmail: String, description: String, pointChange: Int) {
        let tx = PointTransaction(userEmail: userEmail, description: description, pointChange: pointChange)
        do {
            try db.collection("transactions").document().setData(from: tx)
        } catch {
            print("Error inserting transaction: \(error)")
        }
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
                self?.insertTransaction(userEmail: email, description: "Redeemed \(amount) points", pointChange: -amount)
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
                self?.insertTransaction(userEmail: email, description: "Added \(amount) points", pointChange: amount)
                self?.logAudit(action: "Added \(amount) points to \(email)", changedBy: changedBy)
            }
            completion?(error == nil, error?.localizedDescription)
        }
    }

    // MARK: - Admin: loyalty settings

    func updateSettings(
        pointsPerDollar: Int,
        discountPer100Points: Double,
        redemptionThreshold: Int,
        adminWriteEnabled: Bool,
        cashierLoginEnabled: Bool = true,
        cashierLoginStartTime: String = "08:00",
        cashierLoginEndTime: String = "18:00"
    ) {
        errorMessage = nil
        successMessage = nil

        let settings = PointSettings(
            pointsPerDollar: pointsPerDollar,
            discountPer100Points: discountPer100Points,
            redemptionThreshold: redemptionThreshold,
            adminWriteEnabled: adminWriteEnabled,
            cashierLoginEnabled: cashierLoginEnabled,
            cashierLoginStartTime: cashierLoginStartTime,
            cashierLoginEndTime: cashierLoginEndTime
        )

        do {
            try db.collection("settings").document("main").setData(from: settings)
            successMessage = "System configuration has been updated."
            logAudit(action: "Updated system settings", changedBy: currentUser?.email ?? "system")
        } catch {
            errorMessage = "Failed to save settings."
        }
    }

    // MARK: - Super Admin: roles

    func changeUserRole(email: String, newRole: Role) {
        errorMessage = nil
        successMessage = nil

        db.collection("users").document(email).updateData(["role": newRole.rawValue]) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            self.successMessage = "\(email) is now a \(newRole.rawValue)."
            self.logAudit(action: "Changed role of \(email) to \(newRole.rawValue)", changedBy: self.currentUser?.email ?? "system")
        }
    }

    /// Creates a new cashier account. Deliberately does NOT use the default
    /// `Auth.auth()` instance for account creation: calling
    /// `createUser(withEmail:password:)` on the default instance signs the
    /// client in as the newly created user, which would silently eject the
    /// signed-in admin from their own session. A secondary FirebaseApp/Auth
    /// instance is used just to mint the account, then immediately signed
    /// out, leaving the admin's session untouched.
    func createCashier(email: String, name: String, pass: String) {
        errorMessage = nil
        successMessage = nil

        guard !email.isEmpty, !name.isEmpty, !pass.isEmpty else {
            self.errorMessage = "Name, email, and password are required."
            return
        }

        let secondaryAppName = "CashierCreation"
        let secondaryApp: FirebaseApp
        if let existing = FirebaseApp.app(name: secondaryAppName) {
            secondaryApp = existing
        } else {
            guard let options = FirebaseApp.app()?.options else {
                self.errorMessage = "Firebase is not configured."
                return
            }
            FirebaseApp.configure(name: secondaryAppName, options: options)
            guard let created = FirebaseApp.app(name: secondaryAppName) else {
                self.errorMessage = "Failed to prepare account creation."
                return
            }
            secondaryApp = created
        }

        let secondaryAuth = Auth.auth(app: secondaryApp)
        secondaryAuth.createUser(withEmail: email, password: pass) { [weak self] result, error in
            guard let self = self else { return }
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }

            // Only needed the secondary instance to mint the Auth account -
            // it should not remain signed in.
            try? secondaryAuth.signOut()

            let newUser = User(email: email, name: name, role: .cashier)
            do {
                try self.db.collection("users").document(email).setData(from: newUser)
                self.successMessage = "Cashier \(name) created."
                self.logAudit(action: "Created cashier \(email)", changedBy: self.currentUser?.email ?? "system")
            } catch {
                self.errorMessage = "Cashier account created, but failed to save profile data."
            }
        }
    }

    // MARK: - Admin: offers & categories

    func addOffer(title: String, price: String, description: String, category: String = "General", imageUrl: String? = nil) {
        errorMessage = nil
        successMessage = nil

        let resolvedCategory = category.isEmpty ? "General" : category
        let offer = Offer(title: title, price: price, category: resolvedCategory, description: description, imageUrl: imageUrl)

        do {
            try db.collection("offers").document(offer.id).setData(from: offer)
            successMessage = "\(title) is now available."
            logAudit(action: "Added new offer: \(title)", changedBy: currentUser?.email ?? "system")
        } catch {
            errorMessage = "Failed to add offer."
        }
    }

    func deleteOffer(_ offer: Offer) {
        db.collection("offers").document(offer.id).delete()
        logAudit(action: "Deleted offer: \(offer.title)", changedBy: currentUser?.email ?? "system")
    }

    func addCategory(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let category = Category(id: trimmed, name: trimmed)
        do {
            try db.collection("categories").document(trimmed).setData(from: category)
        } catch {
            errorMessage = "Failed to add category."
        }
    }

    func deleteCategory(_ category: Category) {
        db.collection("categories").document(category.id).delete()
    }

    func logout() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            clearUserScopedState()
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
