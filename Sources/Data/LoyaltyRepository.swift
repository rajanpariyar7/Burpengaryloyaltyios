import Foundation
import FirebaseFirestore

/// Firestore access layer, mirroring the collections used by the Android client:
/// `users`, `rewards`, `offers`, `categories`, `transactions`, `auditLogs` and `settings/main`.
final class LoyaltyRepository {
    private let db = Firestore.firestore()

    // MARK: - Listeners

    func observeRewards(_ handler: @escaping ([Reward]) -> Void) -> ListenerRegistration {
        db.collection("rewards").addSnapshotListener { snapshot, _ in
            handler(snapshot?.documents.compactMap { try? $0.data(as: Reward.self) } ?? [])
        }
    }

    func observeOffers(_ handler: @escaping ([Offer]) -> Void) -> ListenerRegistration {
        db.collection("offers").addSnapshotListener { snapshot, _ in
            handler(snapshot?.documents.compactMap { try? $0.data(as: Offer.self) } ?? [])
        }
    }

    func observeCategories(_ handler: @escaping ([Category]) -> Void) -> ListenerRegistration {
        db.collection("categories").addSnapshotListener { snapshot, _ in
            handler(snapshot?.documents.compactMap { try? $0.data(as: Category.self) } ?? [])
        }
    }

    func observeAllUsers(_ handler: @escaping ([User]) -> Void) -> ListenerRegistration {
        db.collection("users").addSnapshotListener { snapshot, _ in
            handler(snapshot?.documents.compactMap { try? $0.data(as: User.self) } ?? [])
        }
    }

    func observeCustomers(_ handler: @escaping ([User]) -> Void) -> ListenerRegistration {
        db.collection("users")
            .whereField("role", isEqualTo: Role.customer.rawValue)
            .addSnapshotListener { snapshot, _ in
                handler(snapshot?.documents.compactMap { try? $0.data(as: User.self) } ?? [])
            }
    }

    func observeTransactions(_ handler: @escaping ([PointTransaction]) -> Void) -> ListenerRegistration {
        db.collection("transactions")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { snapshot, _ in
                handler(snapshot?.documents.compactMap { try? $0.data(as: PointTransaction.self) } ?? [])
            }
    }

    func observeAuditLogs(_ handler: @escaping ([AuditLog]) -> Void) -> ListenerRegistration {
        db.collection("auditLogs")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { snapshot, _ in
                handler(snapshot?.documents.compactMap { try? $0.data(as: AuditLog.self) } ?? [])
            }
    }

    func observePointSettings(_ handler: @escaping (PointSettings?) -> Void) -> ListenerRegistration {
        db.collection("settings").document("main").addSnapshotListener { snapshot, _ in
            handler(try? snapshot?.data(as: PointSettings.self))
        }
    }

    func observeUser(email: String, _ handler: @escaping (User?) -> Void) -> ListenerRegistration? {
        guard !email.isEmpty else {
            handler(nil)
            return nil
        }
        return db.collection("users").document(email).addSnapshotListener { snapshot, _ in
            handler(try? snapshot?.data(as: User.self))
        }
    }

    // MARK: - Users

    func user(email: String) async -> User? {
        guard !email.isEmpty else { return nil }
        return try? await db.collection("users").document(email).getDocument(as: User.self)
    }

    func createUser(_ user: User) async throws {
        try db.collection("users").document(user.email).setData(from: user)
    }

    func updateUser(_ user: User) async throws {
        try db.collection("users").document(user.email).setData(from: user)
    }

    func addStamp(email: String) async throws {
        guard var current = await user(email: email) else { return }
        current.stamps += 1
        current.lifetimeStamps += 1
        try await updateUser(current)
    }

    func resetStamps(email: String) async throws {
        guard var current = await user(email: email) else { return }
        current.stamps = 0
        try await updateUser(current)
    }

    func addPoints(email: String, points: Int) async throws {
        guard var current = await user(email: email) else { return }
        current.points += points
        try await updateUser(current)
    }

    func redeemReward(email: String, reward: Reward) async throws {
        guard var current = await user(email: email) else { return }
        if reward.costInStamps > 0, current.stamps >= reward.costInStamps {
            current.stamps -= reward.costInStamps
        } else if reward.costInPoints > 0, current.points >= reward.costInPoints {
            current.points -= reward.costInPoints
        } else {
            return
        }
        try await updateUser(current)
    }

    func redeemPoints(email: String, points: Int) async throws {
        guard var current = await user(email: email), current.points >= points else { return }
        current.points -= points
        try await updateUser(current)
    }

    // MARK: - Catalog

    func addOffer(_ offer: Offer) async throws {
        var stored = offer
        stored.id = UUID().uuidString
        try db.collection("offers").document(stored.id).setData(from: stored)
    }

    func deleteOffer(_ offer: Offer) async throws {
        try await db.collection("offers").document(offer.id).delete()
    }

    func insertReward(_ reward: Reward) async throws {
        var stored = reward
        stored.id = UUID().uuidString
        try db.collection("rewards").document(stored.id).setData(from: stored)
    }

    func insertCategory(name: String) async throws {
        let category = Category(id: UUID().uuidString, name: name)
        try db.collection("categories").document(category.id).setData(from: category)
    }

    func deleteCategory(_ category: Category) async throws {
        try await db.collection("categories").document(category.id).delete()
    }

    // MARK: - Ledger

    func insertTransaction(_ transaction: PointTransaction) async throws {
        var stored = transaction
        stored.id = UUID().uuidString
        try db.collection("transactions").document(stored.id).setData(from: stored)
    }

    func logAudit(action: String, by email: String) async throws {
        let log = AuditLog(id: UUID().uuidString, action: action, changedBy: email)
        try db.collection("auditLogs").document(log.id).setData(from: log)
    }

    // MARK: - Settings

    func updateSettings(_ settings: PointSettings) async throws {
        try db.collection("settings").document("main").setData(from: settings)
    }

    /// Seeds settings and demo content the first time the store is used, matching
    /// the Android `initializeDb()`. Fails silently when security rules reject the write.
    func initializeDb() async {
        do {
            let settings = try await db.collection("settings").document("main").getDocument()
            if !settings.exists {
                try await updateSettings(PointSettings())
            }

            if await user(email: "admin@example.com") == nil {
                try await createUser(User(email: "admin@example.com", name: "Store Manager", role: .admin))
                try await createUser(User(email: "cashier@example.com", name: "Market Cashier", role: .cashier))

                try await insertReward(Reward(
                    title: "Free Coffee",
                    description: "Get a free medium coffee at the market cafe.",
                    costInStamps: 10
                ))
                try await insertReward(Reward(
                    title: "$5 Off Produce",
                    description: "Get $5 off your next fresh produce purchase.",
                    costInPoints: 500
                ))
                try await addOffer(Offer(
                    title: "Fresh Strawberries",
                    price: "$1.99",
                    category: "FRUITS",
                    description: "OFFER: Amazing value! $1.99 per punnet!"
                ))
                try await insertTransaction(PointTransaction(
                    userEmail: "customer@example.com",
                    description: "Purchase: $5.0 by cashier cashier@example.com",
                    pointChange: 50
                ))
            }
        } catch {
            return
        }
    }
}
