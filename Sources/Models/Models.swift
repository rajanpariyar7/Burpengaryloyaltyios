import Foundation
import FirebaseFirestore

enum Role: String, Codable, CaseIterable {
    case superAdmin = "SUPER_ADMIN"
    case admin = "ADMIN"
    case cashier = "CASHIER"
    case customer = "CUSTOMER"
}

struct User: Codable, Identifiable, Equatable {
    var id: String { email } // email is the Firestore document id, same as Android
    var email: String = ""
    var passwordHash: String = ""
    var name: String = ""
    var role: Role = .customer
    var stamps: Int = 0
    var points: Int = 0
    var lifetimeStamps: Int = 0
    var phone: String = ""
    var customerId: String = ""
}

struct Reward: Codable, Identifiable {
    var id: String = UUID().uuidString
    var title: String = ""
    var description: String = ""
    var costInPoints: Int = 0
    var costInStamps: Int = 0
    var isRedeemed: Bool = false
    var userEmail: String? = nil
}

struct Offer: Codable, Identifiable {
    var id: String = UUID().uuidString
    var title: String = ""
    var price: String = ""
    var category: String = "General"
    var description: String = ""
    var imageUrl: String? = nil
}

struct Category: Codable, Identifiable, Equatable {
    var id: String = ""
    var name: String = ""
}

struct PointSettings: Codable, Identifiable {
    var id: Int = 1
    var pointsPerDollar: Int = 10
    var discountPer100Points: Double = 1.0
    var redemptionThreshold: Int = 100
    var adminWriteEnabled: Bool = true
    var cashierLoginEnabled: Bool = true
    var cashierLoginStartTime: String = "08:00"
    var cashierLoginEndTime: String = "18:00"
}

// Android stores timestamp as a Long (millis since epoch) - mirrored here as Int64
// so JSON encoding lines up exactly with what the Android app reads/writes.
//
// `id` is @DocumentID (not a plain default) so each transaction decoded from
// Firestore gets its actual document id. Without this, every transaction
// would decode with the same "" id and break SwiftUI List's identity.
struct PointTransaction: Codable, Identifiable {
    @DocumentID var id: String?
    var userEmail: String = ""
    var description: String = ""
    var pointChange: Int = 0
    var timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000)

    var date: Date { Date(timeIntervalSince1970: Double(timestamp) / 1000) }
}

// Same @DocumentID fix as PointTransaction, for the same reason - the
// SuperAdminView audit log list needs a real, unique id per row.
struct AuditLog: Codable, Identifiable {
    @DocumentID var id: String?
    var action: String = ""
    var changedBy: String = ""
    var timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
}
