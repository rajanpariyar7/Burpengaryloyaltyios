import Foundation

enum Role: String, Codable, CaseIterable {
    case superAdmin = "SUPER_ADMIN"
    case admin = "ADMIN"
    case cashier = "CASHIER"
    case customer = "CUSTOMER"
}

struct User: Codable, Identifiable, Equatable {
    var id: String { email }
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

struct Reward: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String = ""
    var description: String = ""
    var costInPoints: Int = 0
    var costInStamps: Int = 0
    var isRedeemed: Bool = false
    var userEmail: String?

    // The Android client serializes `isRedeemed` through its boolean getter,
    // which Firestore stores as `redeemed`.
    enum CodingKeys: String, CodingKey {
        case id, title, description, costInPoints, costInStamps
        case isRedeemed = "redeemed"
        case userEmail
    }
}

struct Offer: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String = ""
    var price: String = ""
    var category: String = "General"
    var description: String = ""
    var imageUrl: String?
}

struct PointSettings: Codable, Identifiable, Equatable {
    var id: Int = 1
    var pointsPerDollar: Int = 10
    var discountPer100Points: Double = 1.0
    var redemptionThreshold: Int = 100
    var adminWriteEnabled: Bool = true
    var cashierLoginEnabled: Bool = true
    var cashierLoginStartTime: String = "08:00"
    var cashierLoginEndTime: String = "18:00"
}

struct PointTransaction: Codable, Identifiable, Equatable {
    var id: String = ""
    var userEmail: String = ""
    var description: String = ""
    var pointChange: Int = 0
    var timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000)

    var date: Date { Date(timeIntervalSince1970: Double(timestamp) / 1000) }
}

struct AuditLog: Codable, Identifiable, Equatable {
    var id: String = ""
    var action: String = ""
    var changedBy: String = ""
    var timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000)

    var date: Date { Date(timeIntervalSince1970: Double(timestamp) / 1000) }
}

struct Category: Codable, Identifiable, Equatable {
    var id: String = ""
    var name: String = ""
}

struct AppNotification: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}
