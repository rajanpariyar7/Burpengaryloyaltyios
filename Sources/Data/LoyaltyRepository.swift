import Foundation
import FirebaseFirestore

enum LoyaltyError: LocalizedError {
    case userNotFound
    case insufficientPoints(available: Int)
    case insufficientStamps(available: Int)
    case belowRedemptionThreshold(threshold: Int)
    case notAuthorized
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "That customer could not be found."
        case .insufficientPoints(let available):
            return "Not enough points. Balance is \(available)."
        case .insufficientStamps(let available):
            return "Not enough stamps. Balance is \(available)."
        case .belowRedemptionThreshold(let threshold):
            return "A minimum of \(threshold) points is required to redeem."
        case .notAuthorized:
            return "You do not have permission to perform this action."
        case .invalidInput(let reason):
            return reason
        }
    }
}

/// Firestore access layer, mirroring the collections used by the Android client:
/// `users`, `rewards`, `offers`, `categories`, `transactions`, `auditLogs` and `settings/main`.
///
/// Balance mutations run inside Firestore transactions so concurrent registers cannot
/// clobber each other, and they only touch balance fields rather than rewriting the
/// whole user document.
final class LoyaltyRepository {
    private let db = Firestore.firestore()

    private struct Balances {
        var points: Int
        var stamps: Int
        var lifetimeStamps: Int
    }

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

    func observeTransactions(email: String, _ handler: @escaping ([PointTransaction]) -> Void) -> ListenerRegistration {
        db.collection("transactions")
            .whereField("userEmail", isEqualTo: email)
            .addSnapshotListener { snapshot, _ in
                let transactions = snapshot?.documents.compactMap { try? $0.data(as: PointTransaction.self) } ?? []
                handler(transactions.sorted { $0.timestamp > $1.timestamp })
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
        try db.collection("users").document(user.email).setData(from: user, merge: true)
    }

    func updateUser(_ user: User) async throws {
        try db.collection("users").document(user.email).setData(from: user, merge: true)
    }

    func updateRole(email: String, role: Role) async throws {
        try await db.collection("users").document(email).updateData(["role": role.rawValue])
    }

    /// Atomically applies a balance change; `change` may throw to abort the transaction.
    private func mutateBalances(email: String, change: @escaping (Balances) throws -> Balances) async throws {
        guard !email.isEmpty else { throw LoyaltyError.userNotFound }
        let reference = db.collection("users").document(email)

        _ = try await db.runTransaction { transaction, errorPointer in
            do {
                let snapshot = try transaction.getDocument(reference)
                guard let data = snapshot.data() else { throw LoyaltyError.userNotFound }
                let current = Balances(
                    points: data["points"] as? Int ?? 0,
                    stamps: data["stamps"] as? Int ?? 0,
                    lifetimeStamps: data["lifetimeStamps"] as? Int ?? 0
                )
                let updated = try change(current)
                transaction.updateData(
                    [
                        "points": updated.points,
                        "stamps": updated.stamps,
                        "lifetimeStamps": updated.lifetimeStamps
                    ],
                    forDocument: reference
                )
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }

    func addStamp(email: String) async throws {
        try await mutateBalances(email: email) { current in
            var updated = current
            updated.stamps += 1
            updated.lifetimeStamps += 1
            return updated
        }
    }

    func resetStamps(email: String) async throws {
        try await mutateBalances(email: email) { current in
            var updated = current
            updated.stamps = 0
            return updated
        }
    }

    func addPoints(email: String, points: Int) async throws {
        try await mutateBalances(email: email) { current in
            var updated = current
            updated.points += points
            return updated
        }
    }

    func redeemReward(email: String, reward: Reward) async throws {
        try await mutateBalances(email: email) { current in
            var updated = current
            if reward.costInStamps > 0 {
                guard current.stamps >= reward.costInStamps else {
                    throw LoyaltyError.insufficientStamps(available: current.stamps)
                }
                updated.stamps -= reward.costInStamps
            } else {
                guard current.points >= reward.costInPoints else {
                    throw LoyaltyError.insufficientPoints(available: current.points)
                }
                updated.points -= reward.costInPoints
            }
            return updated
        }
    }

    func redeemPoints(email: String, points: Int, threshold: Int) async throws {
        guard points > 0 else { throw LoyaltyError.invalidInput("Enter a positive number of points.") }
        guard points >= threshold else { throw LoyaltyError.belowRedemptionThreshold(threshold: threshold) }

        try await mutateBalances(email: email) { current in
            guard current.points >= points else {
                throw LoyaltyError.insufficientPoints(available: current.points)
            }
            var updated = current
            updated.points -= points
            return updated
        }
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

    /// Seeds the settings document the first time the store is used, matching the Android
    /// `initializeDb()`. Fails silently when security rules reject the write.
    func initializeDb() async {
        guard let snapshot = try? await db.collection("settings").document("main").getDocument(),
              !snapshot.exists else { return }
        try? await updateSettings(PointSettings())
    }
}
