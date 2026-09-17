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
    @Published var allUsers: [User] = []
    @Published var allTransactions: [PointTransaction] = []
    @Published var offers: [Offer] = []
    @Published var categories: [Category] = []
    @Published var pointSettings: PointSettings?

    /// Customers only, derived from `allUsers`. Kept as a computed property
    /// rather than a second listener so it can never drift out of sync with
    /// `allUsers`/`searchUsers`.
    var allCustomers: [User] { allUsers.filter { $0.role == .customer } }

    private var db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private var userPointsListener: ListenerRegistration?
    private var auditLogsListener: ListenerRegistration?
    private var allUsersListener: ListenerRegistration?
    private var allTransactionsListener: ListenerRegistration?
    private var offersListener: ListenerRegistration?
    private var categoriesListener: ListenerRegistration?
    private var pointSettingsListener: ListenerRegistration?

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
                self.allUsersListener?.remove()
                self.allUsersListener = nil
                self.allUsers = []
                self.allTransactionsListener?.remove()
                self.allTransactionsListener = nil
                self.allTransactions = []
                self.offersListener?.remove()
                self.offersListener = nil
                self.offers = []
                self.categoriesListener?.remove()
                self.categoriesListener = nil
                self.categories = []
                self.pointSettingsListener?.remove()
                self.pointSettingsListener = nil
                self.pointSettings = nil
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

    /// Live user directory, backing SuperAdminRolesTab, AdminCustomersTab
    /// (via `allCustomers`) and `searchUsers`. Same manual-call convention
    /// as `listenToAuditLogs` above - call once the signed-in user is
    /// staff.
    func listenToAllUsers() {
        allUsersListener?.remove()
        allUsersListener = db.collection("users").addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                print("Error fetching users: \(error)")
                return
            }
            guard let docs = snapshot?.documents else { return }
            self?.allUsers = docs.compactMap { try? $0.data(as: User.self) }
        }
    }

    /// Live feed backing AdminStatsTab, AdminTransactionsTab and
    /// SuperAdminTransactionsTab. Assumes a top-level "transactions"
    /// collection separate from "auditLogs" - verify this matches the
    /// collection name the Android app writes to, if points/transactions
    /// stop showing up here after this change.
    func listenToAllTransactions() {
        allTransactionsListener?.remove()
        allTransactionsListener = db.collection("transactions")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching transactions: \(error)")
                    return
                }
                guard let docs = snapshot?.documents else { return }
                self?.allTransactions = docs.compactMap { try? $0.data(as: PointTransaction.self) }
            }
    }

    func listenToOffers() {
        offersListener?.remove()
        offersListener = db.collection("offers").addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                print("Error fetching offers: \(error)")
                return
            }
            guard let docs = snapshot?.documents else { return }
            self?.offers = docs.compactMap { try? $0.data(as: Offer.self) }
        }
    }

    func listenToCategories() {
        categoriesListener?.remove()
        categoriesListener = db.collection("categories").addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                print("Error fetching categories: \(error)")
                return
            }
            guard let docs = snapshot?.documents else { return }
            self?.categories = docs.compactMap { try? $0.data(as: Category.self) }
        }
    }

    /// Single global settings document. Stored at settings/global - adjust
    /// the document path here (and in `updateSettings` below) if the
    /// Android app uses a different path for this doc.
    func listenToPointSettings() {
        pointSettingsListener?.remove()
        pointSettingsListener = db.collection("settings").document("global")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching settings: \(error)")
                    return
                }
                self?.pointSettings = try? snapshot?.data(as: PointSettings.self)
            }
    }

    /// Writes the global points/cashier-schedule config. Both AdminSettingsTab
    /// and SuperAdminConfigTab call this with the same signature.
    func updateSettings(
        pointsPerDollar: Int,
        discountPer100Points: Double,
        redemptionThreshold: Int,
        adminWriteEnabled: Bool,
        cashierLoginEnabled: Bool,
        cashierLoginStartTime: String,
        cashierLoginEndTime: String
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
            try db.collection("settings").document("global").setData(from: settings, merge: true)
            successMessage = "Settings saved"
            logAudit(action: "Updated global settings", changedBy: currentUser?.email ?? "admin")
        } catch {
            errorMessage = "Failed to save settings."
        }
    }

    /// Super Admin: change any user's role. Firestore security rules should
    /// be the real enforcement here; this call assumes they already
    /// restrict this write to super admins.
    func changeUserRole(email: String, newRole: Role) {
        errorMessage = nil
        db.collection("users").document(email).updateData(["role": newRole.rawValue]) { [weak self] error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
            } else {
                self?.logAudit(
                    action: "Changed role of \(email) to \(newRole.rawValue)",
                    changedBy: self?.currentUser?.email ?? "superadmin"
                )
            }
        }
    }

    /// Super Admin: create a cashier account. `Auth.auth().createUser`
    /// signs the SDK in as the *new* user, which would otherwise kick the
    /// signed-in Super Admin out of their own session mid-flow. Creating
    /// the account on a throwaway secondary FirebaseApp instance avoids
    /// touching the primary Auth session; the secondary app is torn down
    /// once the Firestore doc is written.
    func createCashier(email: String, name: String, pass: String) {
        errorMessage = nil
        successMessage = nil
        guard !email.isEmpty, !name.isEmpty, !pass.isEmpty else {
            self.errorMessage = "Name, email and password required"
            return
        }
        guard let options = FirebaseApp.app()?.options else {
            self.errorMessage = "Firebase is not configured."
            return
        }

        let secondaryAppName = "CashierCreation-\(UUID().uuidString)"
        if FirebaseApp.app(name: secondaryAppName) == nil {
            FirebaseApp.configure(name: secondaryAppName, options: options)
        }
        guard let secondaryApp = FirebaseApp.app(name: secondaryAppName) else {
            self.errorMessage = "Could not create cashier account."
            return
        }
        let secondaryAuth = Auth.auth(app: secondaryApp)

        secondaryAuth.createUser(withEmail: email, password: pass) { [weak self] result, error in
            guard let self = self else { return }
            if let error = error {
                self.errorMessage = error.localizedDescription
                FirebaseApp.app(name: secondaryAppName)?.delete { _ in }
                return
            }

            let newUser = User(email: email, passwordHash: pass, name: name, role: .cashier, points: 0)
            do {
                try self.db.collection("users").document(email).setData(from: newUser)
                self.successMessage = "Cashier account created"
                self.logAudit(action: "Created cashier account \(email)", changedBy: self.currentUser?.email ?? "superadmin")
            } catch {
                self.errorMessage = "Failed to save cashier data."
            }

            try? secondaryAuth.signOut()
            FirebaseApp.app(name: secondaryAppName)?.delete { _ in }
        }
    }

    /// AdminManageForm's "Publish Product" flow. `category` may be "" (the
    /// Picker's "General" option is tagged "") - falls back to Offer's own
    /// "General" default in that case.
    func addOffer(title: String, price: String, description: String, category: String) {
        errorMessage = nil
        successMessage = nil
        guard !title.isEmpty else {
            errorMessage = "Title required"
            return
        }
        let offer = Offer(
            id: UUID().uuidString,
            title: title,
            price: price,
            category: category.isEmpty ? "General" : category,
            description: description
        )
        do {
            try db.collection("offers").document(offer.id).setData(from: offer)
            successMessage = "Offer added"
            logAudit(action: "Added offer \(title)", changedBy: currentUser?.email ?? "admin")
        } catch {
            errorMessage = "Failed to add offer."
        }
    }

    func deleteCategory(_ category: Category) {
        errorMessage = nil
        db.collection("categories").document(category.id).delete { [weak self] error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    func addCategory(_ name: String) {
        errorMessage = nil
        let category = Category(id: UUID().uuidString, name: name)
        do {
            try db.collection("categories").document(category.id).setData(from: category)
        } catch {
            self.errorMessage = "Failed to add category."
        }
    }

    func deleteOffer(_ offer: Offer) {
        errorMessage = nil
        db.collection("offers").document(offer.id).delete { [weak self] error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    /// Writes a row to the "transactions" collection that `allTransactions`
    /// listens to, so admin/super-admin reporting reflects real point
    /// activity from `addPoints`/`redeemPoints` below.
    private func recordTransaction(userEmail: String, description: String, pointChange: Int) {
        let tx = PointTransaction(userEmail: userEmail, description: description, pointChange: pointChange)
        do {
            _ = try db.collection("transactions").addDocument(from: tx)
        } catch {
            print("Error recording transaction: \(error)")
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
                self?.recordTransaction(userEmail: email, description: "Redeemed \(amount) points", pointChange: -amount)
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
                self?.recordTransaction(userEmail: email, description: "Added \(amount) points", pointChange: amount)
            }
            completion?(error == nil, error?.localizedDescription)
        }
    }

    /// Cashier flow: redeem points for a customer, filling in `changedBy`
    /// from the signed-in staff account. Thin wrapper around `redeemPoints`
    /// for views (CashierView) that don't want to handle the completion
    /// themselves.
    func redeemPointsCashier(email: String, points: Int) {
        errorMessage = nil
        successMessage = nil
        guard points > 0 else {
            errorMessage = "Enter a valid point amount"
            return
        }
        let staffEmail = currentUser?.email ?? "cashier"
        redeemPoints(email: email, amount: points, changedBy: staffEmail) { [weak self] success, error in
            if success {
                self?.successMessage = "Redeemed \(points) points for \(email)"
            } else {
                self?.errorMessage = error
            }
        }
    }

    /// Synchronous local search over the already-loaded customer list, for
    /// CashierView's "find a customer" flow.
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
            self.allUsersListener?.remove()
            self.allUsersListener = nil
            self.allUsers = []
            self.allTransactionsListener?.remove()
            self.allTransactionsListener = nil
            self.allTransactions = []
            self.offersListener?.remove()
            self.offersListener = nil
            self.offers = []
            self.categoriesListener?.remove()
            self.categoriesListener = nil
            self.categories = []
            self.pointSettingsListener?.remove()
            self.pointSettingsListener = nil
            self.pointSettings = nil
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
