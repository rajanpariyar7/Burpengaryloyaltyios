import Foundation
import FirebaseFirestore
import FirebaseAuth

enum FirestoreServiceError: LocalizedError {
    case notAuthenticated
    case userDocMissing
    case insufficientBalance

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You're not signed in."
        case .userDocMissing: return "Couldn't find your profile."
        case .insufficientBalance: return "Not enough stamps or points for this reward."
        }
    }
}

/// Mirrors `com.example.data.repository.LoyaltyRepository` from the Android
/// app field-for-field, so both apps read and write the exact same data:
///
///   users/{email}        -> User doc, KEYED BY EMAIL (not Firebase UID)
///   rewards/{rewardId}
///   offers/{offerId}
///   transactions/{id}    -> PointTransaction (userEmail, description, pointChange, timestamp)
///
/// Uses the same named Firestore database as Android
/// ("burpengary-fruit-market-loyalty-database"), not the default database.
final class FirestoreService {

    static let shared = FirestoreService()
    private init() {}

    private let db = Firestore.firestore(database: "burpengary-fruit-market-loyalty-database")

    private var currentEmail: String {
        get throws {
            guard let email = Auth.auth().currentUser?.email else {
                throw FirestoreServiceError.notAuthenticated
            }
            return email
        }
    }

    // MARK: - Profile

    func fetchProfile() async throws -> AppUser {
        let email = try currentEmail
        let snapshot = try await db.collection("users").document(email).getDocument()
        guard snapshot.exists else { throw FirestoreServiceError.userDocMissing }
        return try snapshot.data(as: AppUser.self)
    }

    /// Matches Android's `createUser` — document ID is the email itself.
    func createUser(_ user: AppUser) async throws {
        try db.collection("users").document(user.email).setData(from: user)
    }

    func updateUser(_ user: AppUser) async throws {
        try db.collection("users").document(user.email).setData(from: user)
    }

    func lookupUser(email: String) async throws -> AppUser? {
        let snapshot = try await db.collection("users").document(email).getDocument()
        guard snapshot.exists else { return nil }
        return try snapshot.data(as: AppUser.self)
    }

    // MARK: - Rewards

    func fetchRewards() async throws -> [Reward] {
        let snapshot = try await db.collection("rewards").getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Reward.self) }
    }

    /// Matches Android's `redeemReward`: deducts stamps OR points depending
    /// on which the reward costs, run as a transaction so concurrent
    /// redemptions (e.g. cashier + customer app) can't overdraw the balance.
    func redeemReward(email: String, reward: Reward) async throws {
        let userRef = db.collection("users").document(email)

        _ = try await db.runTransaction { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(userRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            let currentStamps = snapshot.data()?["stamps"] as? Int ?? 0
            let currentPoints = snapshot.data()?["points"] as? Int ?? 0

            if reward.costInStamps > 0 {
                guard currentStamps >= reward.costInStamps else {
                    errorPointer?.pointee = NSError(domain: "Redeem", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: FirestoreServiceError.insufficientBalance.localizedDescription
                    ])
                    return nil
                }
                transaction.updateData(["stamps": currentStamps - reward.costInStamps], forDocument: userRef)
            } else if reward.costInPoints > 0 {
                guard currentPoints >= reward.costInPoints else {
                    errorPointer?.pointee = NSError(domain: "Redeem", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: FirestoreServiceError.insufficientBalance.localizedDescription
                    ])
                    return nil
                }
                transaction.updateData(["points": currentPoints - reward.costInPoints], forDocument: userRef)
            }
            return nil
        }
    }

    // MARK: - Offers

    func fetchOffers() async throws -> [Offer] {
        let snapshot = try await db.collection("offers").getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Offer.self) }
    }

    // MARK: - Staff actions (Cashier / Admin / Super Admin)
    // Matches Android's addStamp / addPoints, used from StaffToolsView.

    func addStamp(email: String) async throws {
        guard var user = try await lookupUser(email: email) else { throw FirestoreServiceError.userDocMissing }
        user.stamps += 1
        user.lifetimeStamps += 1
        try await updateUser(user)
    }

    func addPoints(email: String, points: Int) async throws {
        guard var user = try await lookupUser(email: email) else { throw FirestoreServiceError.userDocMissing }
        user.points += points
        try await updateUser(user)
    }

    // MARK: - Settings (settings/main — includes cashier login window)

    func fetchSettings() async throws -> AppSettings {
        let snapshot = try await db.collection("settings").document("main").getDocument()
        guard snapshot.exists else { return AppSettings() } // matches Android's default-on-missing behavior
        return (try? snapshot.data(as: AppSettings.self)) ?? AppSettings()
    }

    func updateSettings(_ settings: AppSettings) async throws {
        try db.collection("settings").document("main").setData(from: settings, merge: true)
    }
}
