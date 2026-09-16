import Foundation
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import UIKit

@MainActor
final class LoyaltyViewModel: ObservableObject {
    @Published private(set) var currentUser: User?
    @Published private(set) var pointSettings: PointSettings?
    @Published private(set) var rewards: [Reward] = []
    @Published private(set) var offers: [Offer] = []
    @Published private(set) var categories: [Category] = []
    @Published private(set) var allUsers: [User] = []
    @Published private(set) var allCustomers: [User] = []
    @Published private(set) var allTransactions: [PointTransaction] = []
    @Published private(set) var auditLogs: [AuditLog] = []
    @Published var notification: AppNotification?

    private let repository = LoyaltyRepository()
    private let auth = Auth.auth()
    private var authListener: AuthStateDidChangeListenerHandle?
    private var listeners: [ListenerRegistration] = []
    private var userListener: ListenerRegistration?
    private var currentUserEmail: String?

    var isSignedIn: Bool { currentUser != nil }

    init() {
        startGlobalListeners()
        authListener = auth.addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.bind(email: user?.email)
            }
        }
        Task { await repository.initializeDb() }
    }

    // MARK: - Wiring

    private func startGlobalListeners() {
        listeners = [
            repository.observePointSettings { [weak self] settings in
                Task { @MainActor in
                    self?.pointSettings = settings
                    self?.enforceCashierAccess()
                }
            },
            repository.observeRewards { [weak self] rewards in
                Task { @MainActor in self?.rewards = rewards }
            },
            repository.observeOffers { [weak self] offers in
                Task { @MainActor in self?.offers = offers }
            },
            repository.observeCategories { [weak self] categories in
                Task { @MainActor in self?.categories = categories }
            },
            repository.observeAllUsers { [weak self] users in
                Task { @MainActor in self?.allUsers = users }
            },
            repository.observeCustomers { [weak self] customers in
                Task { @MainActor in self?.allCustomers = customers }
            },
            repository.observeTransactions { [weak self] transactions in
                Task { @MainActor in self?.allTransactions = transactions }
            },
            repository.observeAuditLogs { [weak self] logs in
                Task { @MainActor in self?.auditLogs = logs }
            }
        ]
    }

    private func bind(email: String?) {
        guard email != currentUserEmail else { return }
        currentUserEmail = email
        userListener?.remove()
        userListener = nil

        guard let email else {
            currentUser = nil
            return
        }
        userListener = repository.observeUser(email: email) { [weak self] user in
            Task { @MainActor in
                self?.currentUser = user
                self?.enforceCashierAccess()
            }
        }
    }

    /// Cashier accounts may only be used while cashier login is enabled and inside the
    /// configured window; outside of it the session is terminated, like on Android.
    private func enforceCashierAccess() {
        guard let user = currentUser, user.role == .cashier else { return }
        let settings = pointSettings ?? PointSettings()

        guard settings.cashierLoginEnabled else {
            forceSignOut(reason: "Cashier login is currently disabled by Admin.")
            return
        }
        if !Self.isTime(withinStart: settings.cashierLoginStartTime, end: settings.cashierLoginEndTime) {
            forceSignOut(reason: "Cashier login is only allowed between \(settings.cashierLoginStartTime) and \(settings.cashierLoginEndTime).")
        }
    }

    static func isTime(_ now: Date = Date(), withinStart start: String, end: String) -> Bool {
        func minutes(_ value: String) -> Int? {
            let parts = value.split(separator: ":")
            guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
            return hour * 60 + minute
        }
        guard let startMinutes = minutes(start), let endMinutes = minutes(end) else { return true }
        let components = Calendar.current.dateComponents([.hour, .minute], from: now)
        let nowMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        if startMinutes > endMinutes {
            return nowMinutes >= startMinutes || nowMinutes <= endMinutes
        }
        return nowMinutes >= startMinutes && nowMinutes <= endMinutes
    }

    private func forceSignOut(reason: String) {
        try? auth.signOut()
        currentUser = nil
        currentUserEmail = nil
        userListener?.remove()
        userListener = nil
        notify("Error", reason)
    }

    func notify(_ title: String, _ message: String) {
        notification = AppNotification(title: title, message: message)
        LocalNotifier.show(title: title, message: message)
    }

    // MARK: - Authentication

    func login(email: String, password: String) {
        guard !email.isEmpty, !password.isEmpty else {
            notify("Error", "Email and Password required")
            return
        }
        Task {
            do {
                try await auth.signIn(withEmail: email, password: password)
                if let user = await repository.user(email: email) {
                    notify("Success", "Logged in as \(user.name)")
                } else {
                    try await repository.createUser(User(
                        email: email,
                        name: String(email.prefix(while: { $0 != "@" })),
                        role: .customer
                    ))
                }
            } catch {
                notify("Error", error.localizedDescription)
            }
        }
    }

    func signInWithGoogle(presenting viewController: UIViewController) {
        Task {
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
                guard let idToken = result.user.idToken?.tokenString else {
                    notify("Error", "Google Sign-In failed")
                    return
                }
                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: result.user.accessToken.tokenString
                )
                let authResult = try await auth.signIn(with: credential)
                guard let email = authResult.user.email else { return }
                let name = authResult.user.displayName ?? String(email.prefix(while: { $0 != "@" }))

                if let existing = await repository.user(email: email) {
                    notify("Success", "Logged in as \(existing.name)")
                } else {
                    try await repository.createUser(User(email: email, name: name, role: .customer, points: 5))
                    notify("Success", "Account created! 5 bonus points awarded.")
                }
            } catch {
                notify("Error", error.localizedDescription)
            }
        }
    }

    func signup(emailOrPhone: String, phone: String, name: String) {
        let identifier = emailOrPhone.isEmpty ? phone : emailOrPhone
        guard !identifier.isEmpty else {
            notify("Error", "Email or Phone required")
            return
        }
        let defaultPassword = "password"
        Task {
            do {
                try await auth.createUser(withEmail: identifier, password: defaultPassword)
                try await repository.createUser(User(
                    email: identifier,
                    passwordHash: defaultPassword,
                    name: name,
                    role: .customer,
                    points: 5,
                    phone: phone
                ))
                notify("Success", "Account created! 5 bonus points awarded. Your password is \(defaultPassword)")
            } catch {
                notify("Error", error.localizedDescription)
            }
        }
    }

    func resetPassword(email: String) {
        guard !email.isEmpty else {
            notify("Error", "Please enter your email to reset password")
            return
        }
        Task {
            do {
                try await auth.sendPasswordReset(withEmail: email)
                notify("Success", "Password reset email sent")
            } catch {
                notify("Error", error.localizedDescription)
            }
        }
    }

    func logout() {
        do {
            try auth.signOut()
            GIDSignIn.sharedInstance.signOut()
            currentUser = nil
            currentUserEmail = nil
            userListener?.remove()
            userListener = nil
        } catch {
            notify("Error", "Failed to logout")
        }
    }

    func changeUserPassword(email: String, newPassword: String) {
        Task {
            guard var user = await repository.user(email: email) else { return }
            user.passwordHash = newPassword
            try? await repository.updateUser(user)
            try? await repository.logAudit(action: "Changed password for \(email)", by: currentUserEmail ?? "system")
            notify("Success", "Password updated for \(email)")
        }
    }

    func createCashier(email: String, name: String, password: String) {
        Task {
            do {
                try await auth.createUser(withEmail: email, password: password)
                try await repository.createUser(User(email: email, passwordHash: password, name: name, role: .cashier))
                try await repository.logAudit(action: "Created cashier \(email)", by: currentUserEmail ?? "system")
                notify("Success", "Cashier \(name) created.")
            } catch {
                notify("Error", error.localizedDescription)
            }
        }
    }

    // MARK: - Loyalty operations

    func addStamp(to email: String) {
        Task {
            try? await repository.addStamp(email: email)
            try? await repository.insertTransaction(PointTransaction(
                userEmail: email,
                description: "Received a stamp",
                pointChange: 0
            ))
            notify("Stamp Added", "Customer \(email) received a stamp.")
        }
    }

    func processPurchase(customerEmail: String, amount: Double) {
        Task {
            let cashier = currentUserEmail ?? "unknown_cashier"
            let pointsEarned = Int(amount * Double(pointSettings?.pointsPerDollar ?? 10))
            try? await repository.addPoints(email: customerEmail, points: pointsEarned)

            let description = "Purchase: \(amount) by cashier \(cashier)"
            try? await repository.insertTransaction(PointTransaction(
                userEmail: customerEmail,
                description: description,
                pointChange: pointsEarned
            ))
            try? await repository.logAudit(
                action: "Added \(pointsEarned) points to \(customerEmail) (Cashier: \(cashier))",
                by: cashier
            )
            notify("Purchase Processed", "Added \(pointsEarned) points to \(customerEmail).")
        }
    }

    func redeemReward(_ reward: Reward) {
        Task {
            guard let email = currentUserEmail else { return }
            try? await repository.redeemReward(email: email, reward: reward)

            try? await repository.insertTransaction(PointTransaction(
                userEmail: email,
                description: "Redeemed: \(reward.title)",
                pointChange: reward.costInPoints > 0 ? -reward.costInPoints : 0
            ))
            try? await repository.logAudit(action: "Self-Redeemed Voucher: \(reward.title)", by: email)
            notify("Reward Redeemed!", "You successfully redeemed: \(reward.title)")
        }
    }

    func redeemPointsAsCashier(email: String, points: Int) {
        Task {
            let cashier = currentUserEmail ?? "unknown_cashier"
            try? await repository.redeemPoints(email: email, points: points)
            try? await repository.insertTransaction(PointTransaction(
                userEmail: email,
                description: "Register Redemption by \(cashier)",
                pointChange: -points
            ))
            try? await repository.logAudit(
                action: "Redeemed \(points) points for customer \(email) (Cashier: \(cashier))",
                by: cashier
            )
            notify("Success", "Redeemed \(points) points for \(email)")
        }
    }

    // MARK: - Catalog management

    func addOffer(title: String, price: String, description: String, category: String = "General", imageUrl: String? = nil) {
        Task {
            try? await repository.addOffer(Offer(
                title: title,
                price: price,
                category: category,
                description: description,
                imageUrl: imageUrl
            ))
            try? await repository.logAudit(action: "Added new offer: \(title)", by: currentUserEmail ?? "system")
            notify("Offer Added", "\(title) is now available.")
        }
    }

    func deleteOffer(_ offer: Offer) {
        Task { try? await repository.deleteOffer(offer) }
    }

    func addCategory(name: String) {
        Task { try? await repository.insertCategory(name: name) }
    }

    func deleteCategory(_ category: Category) {
        Task { try? await repository.deleteCategory(category) }
    }

    // MARK: - Administration

    func updateSettings(
        pointsPerDollar: Int,
        discountPer100Points: Double,
        redemptionThreshold: Int,
        adminWriteEnabled: Bool,
        cashierLoginEnabled: Bool = true,
        cashierLoginStartTime: String = "08:00",
        cashierLoginEndTime: String = "18:00"
    ) {
        Task {
            try? await repository.updateSettings(PointSettings(
                pointsPerDollar: pointsPerDollar,
                discountPer100Points: discountPer100Points,
                redemptionThreshold: redemptionThreshold,
                adminWriteEnabled: adminWriteEnabled,
                cashierLoginEnabled: cashierLoginEnabled,
                cashierLoginStartTime: cashierLoginStartTime,
                cashierLoginEndTime: cashierLoginEndTime
            ))
            try? await repository.logAudit(action: "Updated system settings", by: currentUserEmail ?? "system")
            notify("Settings Saved", "System configuration has been updated.")
        }
    }

    func changeUserRole(email: String, role: Role) {
        Task {
            guard var user = await repository.user(email: email) else { return }
            user.role = role
            try? await repository.updateUser(user)
            try? await repository.logAudit(action: "Changed role of \(email) to \(role.rawValue)", by: currentUserEmail ?? "system")
            notify("Role Updated", "\(email) is now a \(role.rawValue).")
        }
    }

    // MARK: - Queries

    func searchUsers(query: String) -> [User] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return allUsers.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.email.localizedCaseInsensitiveContains(query)
                || (!$0.phone.isEmpty && $0.phone.localizedCaseInsensitiveContains(query))
        }
    }

    func transactions(for email: String) -> [PointTransaction] {
        allTransactions.filter { $0.userEmail == email }.sorted { $0.timestamp > $1.timestamp }
    }
}
