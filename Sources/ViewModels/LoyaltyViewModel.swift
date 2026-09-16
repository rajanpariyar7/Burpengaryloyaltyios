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
    private var sessionListeners: [ListenerRegistration] = []
    private var staffListeners: [ListenerRegistration] = []
    private var currentUserEmail: String?
    private var cashierWindowTimer: Timer?

    var isSignedIn: Bool { currentUser != nil }
    var isStaff: Bool { (currentUser?.role ?? .customer) != .customer }

    init() {
        authListener = auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                self?.bind(email: user?.email)
            }
        }
    }

    // MARK: - Session wiring

    /// Listeners are attached only once a user is authenticated, and the collections that
    /// expose other members' data are attached only for staff roles.
    private func bind(email: String?) {
        guard email != currentUserEmail else { return }
        currentUserEmail = email
        tearDownSession()

        guard let email else {
            currentUser = nil
            return
        }

        sessionListeners = [
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
            repository.observeTransactions(email: email) { [weak self] transactions in
                Task { @MainActor in
                    guard self?.isStaff == false else { return }
                    self?.allTransactions = transactions
                }
            }
        ]
        if let userListener = repository.observeUser(email: email, { [weak self] user in
            Task { @MainActor in self?.apply(user: user) }
        }) {
            sessionListeners.append(userListener)
        }

        startCashierWindowTimer()
        Task { await repository.initializeDb() }
    }

    private func apply(user: User?) {
        let previousRole = currentUser?.role
        currentUser = user
        if user?.role != previousRole {
            attachStaffListenersIfNeeded()
        }
        enforceCashierAccess()
    }

    private func attachStaffListenersIfNeeded() {
        staffListeners.forEach { $0.remove() }
        staffListeners = []

        guard isStaff else {
            allUsers = []
            allCustomers = []
            auditLogs = []
            return
        }
        staffListeners = [
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

    private func tearDownSession() {
        (sessionListeners + staffListeners).forEach { $0.remove() }
        sessionListeners = []
        staffListeners = []
        cashierWindowTimer?.invalidate()
        cashierWindowTimer = nil
        rewards = []
        offers = []
        categories = []
        allUsers = []
        allCustomers = []
        allTransactions = []
        auditLogs = []
    }

    // MARK: - Cashier access window

    /// Cashier accounts may only be used while cashier login is enabled and inside the
    /// configured window. A timer re-checks the window because neither Firestore listener
    /// fires simply because the closing time passed.
    private func startCashierWindowTimer() {
        cashierWindowTimer?.invalidate()
        cashierWindowTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.enforceCashierAccess() }
        }
    }

    func enforceCashierAccess() {
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
        guard let startMinutes = minutesOfDay(start), let endMinutes = minutesOfDay(end) else { return true }
        let components = Calendar.current.dateComponents([.hour, .minute], from: now)
        let nowMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        if startMinutes > endMinutes {
            return nowMinutes >= startMinutes || nowMinutes <= endMinutes
        }
        return nowMinutes >= startMinutes && nowMinutes <= endMinutes
    }

    static func minutesOfDay(_ value: String) -> Int? {
        let parts = value.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]), (0...23).contains(hour),
              let minute = Int(parts[1]), (0...59).contains(minute) else { return nil }
        return hour * 60 + minute
    }

    private func forceSignOut(reason: String) {
        try? auth.signOut()
        currentUser = nil
        currentUserEmail = nil
        tearDownSession()
        notify("Error", reason)
    }

    func notify(_ title: String, _ message: String) {
        notification = AppNotification(title: title, message: message)
        LocalNotifier.show(title: title, message: message)
    }

    private func report(_ error: Error) {
        notify("Error", error.localizedDescription)
    }

    private func requireRole(_ roles: Set<Role>) throws -> User {
        guard let user = currentUser, roles.contains(user.role) else { throw LoyaltyError.notAuthorized }
        return user
    }

    // MARK: - Authentication

    static func isValidEmail(_ value: String) -> Bool {
        let pattern = #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }

    func login(email: String, password: String) {
        guard !email.isEmpty, !password.isEmpty else {
            notify("Error", "Email and Password required")
            return
        }
        Task {
            do {
                try await auth.signIn(withEmail: email, password: password)
                if await repository.user(email: email) == nil {
                    try await repository.createUser(User(
                        email: email,
                        name: String(email.prefix(while: { $0 != "@" })),
                        role: .customer
                    ))
                }
            } catch {
                report(error)
            }
        }
    }

    func signInWithGoogle(presenting viewController: UIViewController) {
        Task {
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
                guard let idToken = result.user.idToken?.tokenString else {
                    throw LoyaltyError.invalidInput("Google Sign-In did not return an identity token.")
                }
                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: result.user.accessToken.tokenString
                )
                let authResult = try await auth.signIn(with: credential)
                guard let email = authResult.user.email else { return }

                if await repository.user(email: email) == nil {
                    let name = authResult.user.displayName ?? String(email.prefix(while: { $0 != "@" }))
                    try await repository.createUser(User(email: email, name: name, role: .customer, points: 5))
                    notify("Welcome!", "Account created — 5 bonus points awarded.")
                }
            } catch {
                report(error)
            }
        }
    }

    func signup(email: String, password: String, name: String, phone: String) {
        guard Self.isValidEmail(email) else {
            notify("Error", "Enter a valid email address. Phone-only signup is not supported.")
            return
        }
        guard password.count >= 6 else {
            notify("Error", "Choose a password of at least 6 characters.")
            return
        }
        Task {
            do {
                try await auth.createUser(withEmail: email, password: password)
                try await repository.createUser(User(
                    email: email,
                    name: name,
                    role: .customer,
                    points: 5,
                    phone: phone
                ))
                notify("Welcome!", "Account created — 5 bonus points awarded.")
            } catch {
                report(error)
            }
        }
    }

    func resetPassword(email: String) {
        guard Self.isValidEmail(email) else {
            notify("Error", "Enter your email address to reset your password")
            return
        }
        Task {
            do {
                try await auth.sendPasswordReset(withEmail: email)
                notify("Success", "Password reset email sent")
            } catch {
                report(error)
            }
        }
    }

    func logout() {
        do {
            try auth.signOut()
            GIDSignIn.sharedInstance.signOut()
            currentUser = nil
            currentUserEmail = nil
            tearDownSession()
        } catch {
            report(error)
        }
    }

    /// Changes the signed-in member's own credential through Firebase Auth; the Firestore
    /// document never stores a password.
    func changeOwnPassword(currentPassword: String, newPassword: String) {
        guard let user = auth.currentUser, let email = user.email else { return }
        guard newPassword.count >= 6 else {
            notify("Error", "Choose a password of at least 6 characters.")
            return
        }
        Task {
            do {
                let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
                try await user.reauthenticate(with: credential)
                try await user.updatePassword(to: newPassword)
                notify("Success", "Your password has been updated.")
            } catch {
                report(error)
            }
        }
    }

    /// Staff cannot set another member's password directly; Firebase sends them a reset link.
    func sendPasswordReset(to email: String) {
        Task {
            do {
                _ = try requireRole([.admin, .superAdmin])
                try await auth.sendPasswordReset(withEmail: email)
                notify("Success", "Password reset email sent to \(email)")
            } catch {
                report(error)
            }
        }
    }

    func createCashier(email: String, name: String, password: String) {
        Task {
            do {
                let actor = try requireRole([.admin, .superAdmin])
                guard Self.isValidEmail(email) else {
                    throw LoyaltyError.invalidInput("Enter a valid cashier email address.")
                }
                guard password.count >= 6 else {
                    throw LoyaltyError.invalidInput("Choose a password of at least 6 characters.")
                }
                try await StaffAccountService.createAccount(email: email, password: password)
                try await repository.createUser(User(email: email, name: name, role: .cashier))
                try await repository.logAudit(action: "Created cashier \(email)", by: actor.email)
                notify("Success", "Cashier \(name) created.")
            } catch {
                report(error)
            }
        }
    }

    // MARK: - Loyalty operations

    func addStamp(to email: String) {
        Task {
            do {
                let actor = try requireRole([.cashier, .admin, .superAdmin])
                try await repository.addStamp(email: email)
                try await repository.insertTransaction(PointTransaction(
                    userEmail: email,
                    description: "Received a stamp",
                    pointChange: 0
                ))
                try await repository.logAudit(action: "Added a stamp for \(email)", by: actor.email)
                notify("Stamp Added", "Customer \(email) received a stamp.")
            } catch {
                report(error)
            }
        }
    }

    func processPurchase(customerEmail: String, amount: Double) {
        Task {
            do {
                let actor = try requireRole([.cashier, .admin, .superAdmin])
                guard amount > 0 else { throw LoyaltyError.invalidInput("Enter a purchase amount above $0.") }

                let pointsEarned = Int(amount * Double(pointSettings?.pointsPerDollar ?? 10))
                try await repository.addPoints(email: customerEmail, points: pointsEarned)
                try await repository.insertTransaction(PointTransaction(
                    userEmail: customerEmail,
                    description: "Purchase: \(amount) by cashier \(actor.email)",
                    pointChange: pointsEarned
                ))
                try await repository.logAudit(
                    action: "Added \(pointsEarned) points to \(customerEmail) (Cashier: \(actor.email))",
                    by: actor.email
                )
                notify("Purchase Processed", "Added \(pointsEarned) points to \(customerEmail).")
            } catch {
                report(error)
            }
        }
    }

    func redeemReward(_ reward: Reward) {
        Task {
            do {
                guard let email = currentUserEmail else { throw LoyaltyError.notAuthorized }
                try await repository.redeemReward(email: email, reward: reward)
                try await repository.insertTransaction(PointTransaction(
                    userEmail: email,
                    description: "Redeemed: \(reward.title)",
                    pointChange: reward.costInPoints > 0 ? -reward.costInPoints : 0
                ))
                try await repository.logAudit(action: "Self-Redeemed Voucher: \(reward.title)", by: email)
                notify("Reward Redeemed!", "You successfully redeemed: \(reward.title)")
            } catch {
                report(error)
            }
        }
    }

    func redeemPointsAsCashier(email: String, points: Int) {
        Task {
            do {
                let actor = try requireRole([.cashier, .admin, .superAdmin])
                let threshold = pointSettings?.redemptionThreshold ?? 100
                try await repository.redeemPoints(email: email, points: points, threshold: threshold)
                try await repository.insertTransaction(PointTransaction(
                    userEmail: email,
                    description: "Register Redemption by \(actor.email)",
                    pointChange: -points
                ))
                try await repository.logAudit(
                    action: "Redeemed \(points) points for customer \(email) (Cashier: \(actor.email))",
                    by: actor.email
                )
                notify("Success", "Redeemed \(points) points for \(email)")
            } catch {
                report(error)
            }
        }
    }

    // MARK: - Catalog management

    func addOffer(title: String, price: String, description: String, category: String = "General", imageUrl: String? = nil) {
        Task {
            do {
                let actor = try requireRole([.admin, .superAdmin])
                guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
                    throw LoyaltyError.invalidInput("An offer needs a title.")
                }
                try await repository.addOffer(Offer(
                    title: title,
                    price: price,
                    category: category,
                    description: description,
                    imageUrl: imageUrl
                ))
                try await repository.logAudit(action: "Added new offer: \(title)", by: actor.email)
                notify("Offer Added", "\(title) is now available.")
            } catch {
                report(error)
            }
        }
    }

    func deleteOffer(_ offer: Offer) {
        Task {
            do {
                let actor = try requireRole([.admin, .superAdmin])
                try await repository.deleteOffer(offer)
                try await repository.logAudit(action: "Deleted offer: \(offer.title)", by: actor.email)
            } catch {
                report(error)
            }
        }
    }

    func addCategory(name: String) {
        Task {
            do {
                _ = try requireRole([.admin, .superAdmin])
                guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
                    throw LoyaltyError.invalidInput("A category needs a name.")
                }
                try await repository.insertCategory(name: name)
            } catch {
                report(error)
            }
        }
    }

    func deleteCategory(_ category: Category) {
        Task {
            do {
                _ = try requireRole([.admin, .superAdmin])
                try await repository.deleteCategory(category)
            } catch {
                report(error)
            }
        }
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
            do {
                let actor = try requireRole([.admin, .superAdmin])
                let current = pointSettings ?? PointSettings()

                if actor.role == .admin, !current.adminWriteEnabled,
                   pointsPerDollar != current.pointsPerDollar
                    || discountPer100Points != current.discountPer100Points
                    || redemptionThreshold != current.redemptionThreshold {
                    throw LoyaltyError.notAuthorized
                }
                if actor.role == .admin, adminWriteEnabled != current.adminWriteEnabled {
                    throw LoyaltyError.notAuthorized
                }

                let settings = try Self.validatedSettings(
                    pointsPerDollar: pointsPerDollar,
                    discountPer100Points: discountPer100Points,
                    redemptionThreshold: redemptionThreshold,
                    adminWriteEnabled: adminWriteEnabled,
                    cashierLoginEnabled: cashierLoginEnabled,
                    cashierLoginStartTime: cashierLoginStartTime,
                    cashierLoginEndTime: cashierLoginEndTime
                )
                try await repository.updateSettings(settings)
                try await repository.logAudit(action: "Updated system settings", by: actor.email)
                notify("Settings Saved", "System configuration has been updated.")
            } catch {
                report(error)
            }
        }
    }

    static func validatedSettings(
        pointsPerDollar: Int,
        discountPer100Points: Double,
        redemptionThreshold: Int,
        adminWriteEnabled: Bool,
        cashierLoginEnabled: Bool,
        cashierLoginStartTime: String,
        cashierLoginEndTime: String
    ) throws -> PointSettings {
        guard (1...1000).contains(pointsPerDollar) else {
            throw LoyaltyError.invalidInput("Points per $1 must be between 1 and 1000.")
        }
        guard (1...100_000).contains(redemptionThreshold) else {
            throw LoyaltyError.invalidInput("The redemption threshold must be between 1 and 100000 points.")
        }
        guard discountPer100Points > 0, discountPer100Points <= 100 else {
            throw LoyaltyError.invalidInput("The discount per 100 points must be between $0.01 and $100.")
        }
        guard minutesOfDay(cashierLoginStartTime) != nil, minutesOfDay(cashierLoginEndTime) != nil else {
            throw LoyaltyError.invalidInput("Cashier login times must use 24-hour HH:mm format.")
        }
        return PointSettings(
            pointsPerDollar: pointsPerDollar,
            discountPer100Points: discountPer100Points,
            redemptionThreshold: redemptionThreshold,
            adminWriteEnabled: adminWriteEnabled,
            cashierLoginEnabled: cashierLoginEnabled,
            cashierLoginStartTime: cashierLoginStartTime,
            cashierLoginEndTime: cashierLoginEndTime
        )
    }

    func changeUserRole(email: String, role: Role) {
        Task {
            do {
                let actor = try requireRole([.superAdmin])
                guard email != actor.email else {
                    throw LoyaltyError.invalidInput("You cannot change your own role.")
                }
                try await repository.updateRole(email: email, role: role)
                try await repository.logAudit(
                    action: "Changed role of \(email) to \(role.rawValue)",
                    by: actor.email
                )
                notify("Role Updated", "\(email) is now a \(role.rawValue).")
            } catch {
                report(error)
            }
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
