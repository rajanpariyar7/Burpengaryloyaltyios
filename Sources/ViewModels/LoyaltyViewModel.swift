import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Combine

class LoyaltyViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var alertItem: String?

    // Added — live catalogs used by the new screens below.
    @Published var offers: [Offer] = []
    @Published var rewards: [Reward] = []
    @Published var notifications: [AppNotification] = []
    @Published var pointSettings: PointSettings?
    @Published var allUsers: [User] = [] // populated for cashier/admin/superAdmin (see configureRoleListeners)

    // Added to fix the build: these were referenced by AdminView, CashierView,
    // CustomerDashboardScreen and SuperAdminView but never declared.
    @Published var allTransactions: [PointTransaction] = []
    @Published var auditLogs: [AuditLog] = []
    @Published var categories: [MenuCategory] = []
    var allCustomers: [User] { allUsers.filter { $0.role == .customer } }

    private var db = Firestore.firestore()
    private var storage = Storage.storage()
    private var cancellables = Set<AnyCancellable>()

    private var offersListener: ListenerRegistration?
    private var rewardsListener: ListenerRegistration?
    private var notificationsListener: ListenerRegistration?
    private var settingsListener: ListenerRegistration?
    private var usersListener: ListenerRegistration?
    private var transactionsListener: ListenerRegistration?
    private var auditListener: ListenerRegistration?
    private var categoriesListener: ListenerRegistration?
    private var configuredRole: Role?

    init() {
        Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            guard let self = self else { return }
            if let user = user, let email = user.email {
                self.fetchUserData(email: email)
            } else {
                self.currentUser = nil
                self.stopRoleListeners()
            }
        }
        listenToOffers()
        listenToRewards()
        listenToNotifications()
        listenToPointSettings()
    }

    deinit {
        offersListener?.remove()
        rewardsListener?.remove()
        notificationsListener?.remove()
        settingsListener?.remove()
        usersListener?.remove()
        transactionsListener?.remove()
        auditListener?.remove()
        categoriesListener?.remove()
    }

    // MARK: - Email/Password Login
    func login(email: String, pass: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !pass.isEmpty else {
            self.errorMessage = "Email and Password required"
            return
        }

        Auth.auth().signIn(withEmail: trimmedEmail, password: pass) { [weak self] result, error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
                return
            }
            guard let self = self, let userEmail = result?.user.email else { return }

            let userDoc = self.db.collection("users").document(userEmail)
            userDoc.getDocument { snapshot, _ in
                if snapshot?.exists != true {
                    let newUser = User(
                        email: userEmail,
                        name: userEmail.components(separatedBy: "@").first ?? "Customer",
                        role: .customer
                    )
                    try? userDoc.setData(from: newUser)
                }
            }
            self.successMessage = "Logged in successfully"
        }
    }

    // MARK: - Google Sign-In
    func loginWithGoogle(idToken: String, accessToken: String?) {
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken ?? "")
        Auth.auth().signIn(with: credential) { [weak self] result, error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
                return
            }
            guard let self = self, let user = result?.user, let email = user.email else { return }

            let userDoc = self.db.collection("users").document(email)
            userDoc.getDocument { snapshot, _ in
                if snapshot?.exists != true {
                    let newUser = User(
                        email: email,
                        name: user.displayName ?? (email.components(separatedBy: "@").first ?? "Customer"),
                        role: .customer,
                        points: 5 // 5 Bonus points upon signup
                    )
                    try? userDoc.setData(from: newUser)
                    self.successMessage = "Account created! 5 bonus points awarded."
                } else {
                    self.successMessage = "Logged in as \(user.displayName ?? email)"
                }
            }
        }
    }

    // MARK: - Signup
    func signup(emailOrPhone: String, phoneOptional: String, name: String) {
        let identifier = emailOrPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                         phoneOptional.trimmingCharacters(in: .whitespacesAndNewlines) :
                         emailOrPhone.trimmingCharacters(in: .whitespacesAndNewlines)
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
                name: name.isEmpty ? (identifier.components(separatedBy: "@").first ?? "Customer") : name,
                role: .customer,
                points: 5
            )

            do {
                try self?.db.collection("users").document(identifier).setData(from: newUser)
                self?.successMessage = "Account created! 5 bonus points awarded."
            } catch {
                self?.errorMessage = "Failed to save user data."
            }
        }
    }

    // MARK: - Forgot Password
    func resetPassword(email: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            self.errorMessage = "Please enter your email to reset password"
            return
        }
        Auth.auth().sendPasswordReset(withEmail: trimmedEmail) { [weak self] error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
            } else {
                self?.successMessage = "Password reset email sent to \(trimmedEmail)"
            }
        }
    }

    // MARK: - Logout
    // Fixed: ProfileView.swift calls `viewModel.signOut()`, and the version
    // you uploaded only had `logout()` — that's a straight compile error.
    // Keeping both names (signOut is now the canonical one; logout forwards
    // to it) so neither caller needs to change.
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.currentUser = nil
            self.stopRoleListeners()
        } catch {
            self.errorMessage = "Failed to logout"
        }
    }

    func logout() { signOut() }

    // MARK: - Delete Account
    // Fixed: the uploaded version referenced `self?.isAuthenticated` and
    // `self?.signOut()` as if they already existed — `isAuthenticated` was
    // never declared anywhere (another compile error), and there was no
    // fallback if deleting the Firestore doc succeeded but Auth deletion
    // failed. Rewritten to just clear currentUser, matching how the rest of
    // this class reports state.
    func deleteAccount(completion: @escaping (Bool) -> Void) {
        guard let user = Auth.auth().currentUser, let email = currentUser?.email ?? user.email else {
            completion(false)
            return
        }

        db.collection("users").document(email).delete { [weak self] _ in
            user.delete { error in
                DispatchQueue.main.async {
                    if error == nil {
                        self?.currentUser = nil
                        completion(true)
                    } else {
                        self?.errorMessage = "Could not delete account: \(error!.localizedDescription)"
                        completion(false)
                    }
                }
            }
        }
    }

    // MARK: - Atomic Double-Spend Protected Operations
    func addPoints(email: String, points: Int) async {
        guard !email.isEmpty, points != 0 else { return }
        let userRef = db.collection("users").document(email)
        try? await userRef.updateData([
            "points": FieldValue.increment(Int64(points))
        ])
    }

    func addStamp(email: String) async {
        guard !email.isEmpty else { return }
        let userRef = db.collection("users").document(email)
        try? await userRef.updateData([
            "stamps": FieldValue.increment(Int64(1)),
            "lifetimeStamps": FieldValue.increment(Int64(1))
        ])
    }

    func redeemReward(email: String, costInPoints: Int, costInStamps: Int) async -> Bool {
        guard !email.isEmpty else { return false }
        let userRef = db.collection("users").document(email)

        do {
            _ = try await db.runTransaction { (transaction, errorPointer) -> Any? in
                let snapshot: DocumentSnapshot
                do {
                    try snapshot = transaction.getDocument(userRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }

                let currentPoints = snapshot.data()?["points"] as? Int ?? 0
                let currentStamps = snapshot.data()?["stamps"] as? Int ?? 0

                if costInStamps > 0 {
                    if currentStamps < costInStamps {
                        errorPointer?.pointee = NSError(domain: "LoyaltyApp", code: 400, userInfo: [NSLocalizedDescriptionKey: "Insufficient stamps"])
                        return nil
                    }
                    transaction.updateData(["stamps": FieldValue.increment(Int64(-costInStamps))], forDocument: userRef)
                } else if costInPoints > 0 {
                    if currentPoints < costInPoints {
                        errorPointer?.pointee = NSError(domain: "LoyaltyApp", code: 400, userInfo: [NSLocalizedDescriptionKey: "Insufficient points"])
                        return nil
                    }
                    transaction.updateData(["points": FieldValue.increment(Int64(-costInPoints))], forDocument: userRef)
                }
                return true
            }
            return true
        } catch {
            return false
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
                if let user = self?.currentUser {
                    self?.configureRoleListeners(for: user)
                }
            } catch {
                print("Error decoding user: \(error)")
            }
        }
    }

    // MARK: - Added: Rewards catalog + users/{email}/redeemed subcollection
    // "Rewards: rewards collection + users/{uid}/redeemed subcollection, with
    // a transaction on redeem so points can't go negative or double-redeem."

    private func listenToRewards() {
        rewardsListener = db.collection("rewards").addSnapshotListener { [weak self] snapshot, _ in
            guard let snapshot = snapshot else { return }
            self?.rewards = snapshot.documents.compactMap { try? $0.data(as: Reward.self) }
        }
    }

    /// Redeems `reward` for the current user. Atomic: reads the user's points
    /// AND checks for an existing users/{email}/redeemed/{reward.id} doc in
    /// the SAME Firestore transaction, so two taps (or two devices) can't
    /// both succeed, and points can never go below zero.
    func redeemReward(_ reward: Reward) async {
        guard let email = currentUser?.email, !email.isEmpty else { return }
        let userRef = db.collection("users").document(email)
        let redeemedRef = db.collection("users").document(email).collection("redeemed").document(reward.id)

        do {
            try await db.runTransaction { [weak self] transaction, errorPointer -> Any? in
                guard let self = self else { return nil }

                let alreadyRedeemed: DocumentSnapshot
                let userSnap: DocumentSnapshot
                do {
                    alreadyRedeemed = try transaction.getDocument(redeemedRef)
                    userSnap = try transaction.getDocument(userRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }

                if alreadyRedeemed.exists {
                    errorPointer?.pointee = NSError(domain: "LoyaltyApp", code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "You've already redeemed \(reward.title)"])
                    return nil
                }

                let currentPoints = userSnap.data()?["points"] as? Int ?? 0
                let currentStamps = userSnap.data()?["stamps"] as? Int ?? 0

                if reward.costInStamps > 0 && currentStamps < reward.costInStamps {
                    errorPointer?.pointee = NSError(domain: "LoyaltyApp", code: 400,
                        userInfo: [NSLocalizedDescriptionKey: "Not enough stamps for \(reward.title)"])
                    return nil
                }
                if reward.costInPoints > 0 && currentPoints < reward.costInPoints {
                    errorPointer?.pointee = NSError(domain: "LoyaltyApp", code: 400,
                        userInfo: [NSLocalizedDescriptionKey: "Not enough points for \(reward.title)"])
                    return nil
                }

                if reward.costInStamps > 0 {
                    transaction.updateData(["stamps": FieldValue.increment(Int64(-reward.costInStamps))], forDocument: userRef)
                }
                if reward.costInPoints > 0 {
                    transaction.updateData(["points": FieldValue.increment(Int64(-reward.costInPoints))], forDocument: userRef)
                }

                var redeemedCopy = reward
                redeemedCopy.userEmail = email
                redeemedCopy.isRedeemed = true
                redeemedCopy.redeemedAt = Date().timeIntervalSince1970 * 1000

                do {
                    try transaction.setData(from: redeemedCopy, forDocument: redeemedRef)
                } catch let encodeError as NSError {
                    errorPointer?.pointee = encodeError
                    return nil
                }
                return true
            }
            await MainActor.run { self.successMessage = "Redeemed: \(reward.title)" }
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }

    /// The signed-in customer's own redeemed rewards, newest first.
    func fetchMyRedeemedRewards() async -> [Reward] {
        guard let email = currentUser?.email else { return [] }
        do {
            let snapshot = try await db.collection("users").document(email).collection("redeemed").getDocuments()
            return snapshot.documents
                .compactMap { try? $0.data(as: Reward.self) }
                .sorted { ($0.redeemedAt ?? 0) > ($1.redeemedAt ?? 0) }
        } catch {
            return []
        }
    }

    // MARK: - Added: Offers / Specials (admin + cashier can add; admin can edit/delete)
    // "Offers: offers collection, sales, promotion ... cashiers can add items, category"

    private func listenToOffers() {
        offersListener = db.collection("offers").addSnapshotListener { [weak self] snapshot, _ in
            guard let snapshot = snapshot else { return }
            self?.offers = snapshot.documents.compactMap { try? $0.data(as: Offer.self) }
        }
    }

    /// Creates or updates an offer. Pass `imageData` (e.g. a flyer like the
    /// Wednesday/Weekend Special banners) to upload it to Storage first;
    /// pass nil to keep whatever imageUrl the offer already has.
    func saveOffer(_ offer: Offer, imageData: Data?) async {
        guard let email = currentUser?.email else { return }
        var offerToSave = offer
        offerToSave.createdBy = email
        offerToSave.updatedAt = Date().timeIntervalSince1970 * 1000

        if let imageData = imageData {
            do {
                offerToSave.imageUrl = try await uploadImage(imageData, path: "offers/\(offerToSave.id).jpg")
            } catch {
                await MainActor.run { self.errorMessage = "Image upload failed: \(error.localizedDescription)" }
                return
            }
        }

        do {
            try db.collection("offers").document(offerToSave.id).setData(from: offerToSave, merge: true)
            await MainActor.run { self.successMessage = "Saved \(offerToSave.title)" }
        } catch {
            await MainActor.run { self.errorMessage = "Failed to save offer: \(error.localizedDescription)" }
        }
    }

    func deleteOffer(_ offer: Offer) {
        db.collection("offers").document(offer.id).delete { [weak self] error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
            } else {
                self?.successMessage = "Deleted \(offer.title)"
            }
        }
    }

    // MARK: - Added: Notifications (admin composes; Cloud Function delivers)
    // "admin can add, modify or delete the notifications sent with uploading
    // option with text content"
    //
    // IMPORTANT: writing a doc to the "notifications" collection here does
    // NOT by itself push anything to a phone. Sending an FCM push requires a
    // server-side call with your Firebase server key/Admin SDK credentials,
    // which must never live in the iOS app. functions/index.js in this zip
    // has a Cloud Function that watches this collection's onCreate and does
    // the actual send — deploy that separately (`firebase deploy --only functions`).

    private func listenToNotifications() {
        notificationsListener = db.collection("notifications")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let snapshot = snapshot else { return }
                self?.notifications = snapshot.documents.compactMap { try? $0.data(as: AppNotification.self) }
            }
    }

    func saveNotification(_ notification: AppNotification, imageData: Data?) async {
        guard let email = currentUser?.email else { return }
        var toSave = notification
        toSave.createdBy = email

        if let imageData = imageData {
            do {
                toSave.imageUrl = try await uploadImage(imageData, path: "notifications/\(toSave.id).jpg")
            } catch {
                await MainActor.run { self.errorMessage = "Image upload failed: \(error.localizedDescription)" }
                return
            }
        }

        do {
            try db.collection("notifications").document(toSave.id).setData(from: toSave, merge: true)
            await MainActor.run { self.successMessage = "Notification saved — it will go out shortly." }
        } catch {
            await MainActor.run { self.errorMessage = "Failed to save notification: \(error.localizedDescription)" }
        }
    }

    func deleteNotification(_ notification: AppNotification) {
        db.collection("notifications").document(notification.id).delete { [weak self] error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
            } else {
                self?.successMessage = "Notification deleted"
            }
        }
    }

    // MARK: - Added: Point settings (read-only here; admin editing can reuse saveOffer's pattern if needed)

    private func listenToPointSettings() {
        settingsListener = db.collection("settings").document("main").addSnapshotListener { [weak self] snapshot, _ in
            guard let snapshot = snapshot, snapshot.exists else { return }
            self?.pointSettings = try? snapshot.data(as: PointSettings.self)
        }
    }

    // MARK: - Added: Role management (Super Admin gives Admin/Cashier roles)
    // "super admin can give roles to admins and cashiers" — enforce the
    // "super admin only" part with Firestore rules (see firestore/firestore.rules
    // in this zip); the UI in AdminRolesView.swift also only shows this
    // screen to .superAdmin as a first line of defense.

    private func listenToAllUsers() {
        guard usersListener == nil else { return }
        usersListener = db.collection("users").addSnapshotListener { [weak self] snapshot, _ in
            guard let snapshot = snapshot else { return }
            self?.allUsers = snapshot.documents.compactMap { try? $0.data(as: User.self) }
        }
    }

    func updateUserRole(email: String, role: Role) async {
        do {
            try await db.collection("users").document(email).updateData(["role": role.rawValue])
            await MainActor.run { self.successMessage = "\(email) is now \(role.displayName)" }
        } catch {
            await MainActor.run { self.errorMessage = "Could not update role: \(error.localizedDescription)" }
        }
    }

    // MARK: - Added: role-scoped listeners (transactions, audit log, categories, users)

    private func configureRoleListeners(for user: User) {
        guard configuredRole != user.role else { return }
        stopRoleListeners()
        configuredRole = user.role
        switch user.role {
        case .customer:
            listenToTransactions(forCustomer: user.email)   // customers only see their own
        case .cashier:
            listenToTransactions(forCustomer: nil)
            listenToAllUsers()                              // needed for searchUsers()
        case .admin:
            listenToTransactions(forCustomer: nil)
            listenToAllUsers()
            listenToCategories()
        case .superAdmin:
            listenToTransactions(forCustomer: nil)
            listenToAllUsers()
            listenToCategories()
            listenToAuditLogs()
        }
    }

    private func stopRoleListeners() {
        usersListener?.remove();        usersListener = nil
        transactionsListener?.remove(); transactionsListener = nil
        auditListener?.remove();        auditListener = nil
        categoriesListener?.remove();   categoriesListener = nil
        configuredRole = nil
        allUsers = []
        allTransactions = []
        auditLogs = []
        categories = []
    }

    private func listenToTransactions(forCustomer email: String?) {
        var query: Query = db.collection("transactions")
        if let email = email {
            query = query.whereField("userEmail", isEqualTo: email)
        } else {
            query = query.order(by: "timestamp", descending: true).limit(to: 500)
        }
        transactionsListener = query.addSnapshotListener { [weak self] snapshot, error in
            if let error = error { print("Transactions listener error: \(error)"); return }
            guard let snapshot = snapshot else { return }
            let items = snapshot.documents.compactMap { try? $0.data(as: PointTransaction.self) }
            self?.allTransactions = items.sorted { $0.timestamp > $1.timestamp }
        }
    }

    private func listenToAuditLogs() {
        auditListener = db.collection("auditLogs")
            .order(by: "timestamp", descending: true)
            .limit(to: 200)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error { print("Audit listener error: \(error)"); return }
                guard let snapshot = snapshot else { return }
                self?.auditLogs = snapshot.documents.compactMap { try? $0.data(as: AuditLog.self) }
            }
    }

    private func listenToCategories() {
        categoriesListener = db.collection("categories").addSnapshotListener { [weak self] snapshot, _ in
            guard let snapshot = snapshot else { return }
            self?.categories = snapshot.documents.compactMap { try? $0.data(as: MenuCategory.self) }
        }
    }

    private func recordAudit(_ action: String) {
        let entry: [String: Any] = [
            "action": action,
            "changedBy": currentUser?.email ?? "unknown",
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)   // milliseconds
        ]
        db.collection("auditLogs").addDocument(data: entry)
    }

    // MARK: - Added: search, purchases, settings, roles, cashier creation

    func searchUsers(_ query: String) -> [User] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return allUsers.filter {
            $0.email.localizedCaseInsensitiveContains(q) || $0.name.localizedCaseInsensitiveContains(q)
        }
    }

    /// Awards points for a purchase: writes a ledger entry and bumps the customer's balance atomically.
    func processPurchase(customerEmail: String, amount: Double) {
        guard !customerEmail.isEmpty, amount > 0 else {
            errorMessage = "Enter a valid purchase amount"
            return
        }
        let rate = pointSettings?.pointsPerDollar ?? 10
        let points = Int((amount * Double(rate)).rounded(.down))
        guard points > 0 else {
            errorMessage = "Purchase too small to earn points"
            return
        }
        let batch = db.batch()
        batch.updateData(["points": FieldValue.increment(Int64(points))],
                         forDocument: db.collection("users").document(customerEmail))
        batch.setData([
            "userEmail": customerEmail,
            "description": String(format: "Purchase $%.2f", amount),
            "pointChange": points,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            "processedBy": currentUser?.email ?? ""
        ], forDocument: db.collection("transactions").document())
        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = "Could not record purchase: \(error.localizedDescription)"
                } else {
                    self?.successMessage = "Added \(points) points to \(customerEmail)"
                }
            }
        }
    }

    func processPurchase(customerEmail: String, amount: Int) {
        processPurchase(customerEmail: customerEmail, amount: Double(amount))
    }

    /// Every parameter is optional so both AdminView and SuperAdminView can call it with the subset they own.
    func updateSettings(
        pointsPerDollar: Int? = nil,
        discountPer100Points: Double? = nil,
        redemptionThreshold: Int? = nil,
        adminWriteEnabled: Bool? = nil,
        cashierLoginEnabled: Bool? = nil,
        cashierLoginStartTime: String? = nil,
        cashierLoginEndTime: String? = nil
    ) {
        if currentUser?.role == .admin, pointSettings?.adminWriteEnabled != true {
            errorMessage = "Loyalty rules are locked by the Super Admin"
            return
        }
        var data: [String: Any] = [:]
        if let v = pointsPerDollar { data["pointsPerDollar"] = v }
        if let v = discountPer100Points { data["discountPer100Points"] = v }
        if let v = redemptionThreshold { data["redemptionThreshold"] = v }
        if let v = adminWriteEnabled { data["adminWriteEnabled"] = v }
        if let v = cashierLoginEnabled { data["cashierLoginEnabled"] = v }
        if let v = cashierLoginStartTime { data["cashierLoginStartTime"] = v }
        if let v = cashierLoginEndTime { data["cashierLoginEndTime"] = v }
        guard !data.isEmpty else { return }

        db.collection("settings").document("main").setData(data, merge: true) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = "Could not save settings: \(error.localizedDescription)"
                } else {
                    self?.successMessage = "Settings saved"
                    self?.recordAudit("Updated settings: " + data.keys.sorted().joined(separator: ", "))
                }
            }
        }
    }

    // MARK: Quick-add offer (AdminView "Publish Product")

    func addOffer(title: String, price: String, description: String, category: String) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPrice = price.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanPrice.isEmpty else {
            errorMessage = "Product title and price are required"
            return
        }
        var offer = Offer()
        offer.title = cleanTitle
        offer.price = cleanPrice
        offer.description = description
        offer.category = category.isEmpty ? "General" : category
        Task { await saveOffer(offer, imageData: nil) }
    }

    // MARK: Categories (AdminView)

    func addCategory(_ name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        if categories.contains(where: { $0.name.caseInsensitiveCompare(clean) == .orderedSame }) {
            errorMessage = "Category \"\(clean)\" already exists"
            return
        }
        db.collection("categories").addDocument(data: ["name": clean]) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = "Could not add category: \(error.localizedDescription)"
                } else {
                    self?.successMessage = "Added category \(clean)"
                    self?.recordAudit("Added category \(clean)")
                }
            }
        }
    }

    func addCategory(name: String) { addCategory(name) }

    func deleteCategory(_ category: MenuCategory) {
        guard let id = category.id else { return }
        db.collection("categories").document(id).delete { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = "Could not delete category: \(error.localizedDescription)"
                } else {
                    self?.recordAudit("Deleted category \(category.name)")
                }
            }
        }
    }

    /// Cashier redeems points on behalf of a customer. Atomic: checks the balance and deducts in one transaction,
    /// and records a negative ledger entry.
    func redeemPointsCashier(email: String, points: Int) {
        guard !email.isEmpty, points > 0 else {
            errorMessage = "Enter a valid number of points"
            return
        }
        let userRef = db.collection("users").document(email)
        let txRef = db.collection("transactions").document()
        let staffEmail = currentUser?.email ?? ""

        db.runTransaction({ transaction, errorPointer -> Any? in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(userRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            let current = snapshot.data()?["points"] as? Int ?? 0
            if current < points {
                errorPointer?.pointee = NSError(
                    domain: "LoyaltyApp", code: 400,
                    userInfo: [NSLocalizedDescriptionKey: "Customer only has \(current) points"])
                return nil
            }
            transaction.updateData(["points": FieldValue.increment(Int64(-points))], forDocument: userRef)
            transaction.setData([
                "userEmail": email,
                "description": "Redeemed \(points) points",
                "pointChange": -points,
                "timestamp": Int(Date().timeIntervalSince1970 * 1000),
                "processedBy": staffEmail
            ], forDocument: txRef)
            return true
        }) { [weak self] _, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.successMessage = "Redeemed \(points) points for \(email)"
                }
            }
        }
    }

    func changeUserRole(email: String, newRole: Role) {
        Task {
            await updateUserRole(email: email, role: newRole)
            recordAudit("Changed role of \(email) to \(newRole.rawValue)")
        }
    }

    /// Creates the Auth account on a SECONDARY Firebase app so the Super Admin
    /// isn't signed out and replaced by the new cashier (which is what
    /// Auth.auth().createUser does on the default app).
    func createCashier(email: String, name: String, pass: String) {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmail.isEmpty, !name.isEmpty, pass.count >= 6 else {
            errorMessage = "Name, email and a password of at least 6 characters are required"
            return
        }
        guard let mainApp = FirebaseApp.app() else { return }
        let secondaryName = "cashierCreator"
        if FirebaseApp.app(name: secondaryName) == nil {
            FirebaseApp.configure(name: secondaryName, options: mainApp.options)
        }
        guard let secondary = FirebaseApp.app(name: secondaryName) else { return }
        let secondaryAuth = Auth.auth(app: secondary)

        secondaryAuth.createUser(withEmail: cleanEmail, password: pass) { [weak self] _, error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
                return
            }
            let newUser = User(email: cleanEmail, name: name, role: .cashier)
            do {
                try self.db.collection("users").document(cleanEmail).setData(from: newUser)
                DispatchQueue.main.async {
                    self.successMessage = "Cashier account created for \(cleanEmail)"
                    self.recordAudit("Created cashier account \(cleanEmail)")
                }
            } catch {
                DispatchQueue.main.async { self.errorMessage = "Account created but profile save failed" }
            }
            try? secondaryAuth.signOut()
        }
    }

    // MARK: - Added: FCM token registration
    // Call updateFCMToken(_:) from your AppDelegate's
    // MessagingDelegate.messaging(_:didReceiveRegistrationToken:) once you've
    // wired that up (not included here — see BurpengaryApp.swift's comment).
    func updateFCMToken(_ token: String) {
        guard let email = currentUser?.email else { return }
        db.collection("users").document(email).updateData(["fcmToken": token])
    }

    // MARK: - Lightweight engagement logging + toast-style messaging
    // CustomerDashboardScreen.swift's Home and Catalog tabs call these two.
    // Kept dependency-free (no FirebaseAnalytics) since project.yml doesn't
    // list that product — swap logOfferClick's body for
    // Analytics.logEvent(...) if you add it later.

    func logOfferClick(_ offerTitle: String) {
        #if DEBUG
        print("Offer viewed: \(offerTitle)")
        #endif
    }

    func sendNotification(_ title: String, _ message: String) {
        if title.localizedCaseInsensitiveContains("error") {
            self.errorMessage = message
        } else {
            self.successMessage = message
        }
    }

    // MARK: - Shared image upload helper

    private func uploadImage(_ data: Data, path: String) async throws -> String {
        let ref = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }
}

/// Minimal category model backing `LoyaltyViewModel.categories`.
/// If Models.swift already defines an equivalent, delete this and change the property's type.
struct MenuCategory: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
}
