import Foundation

enum Role: String, Codable {
    case superAdmin = "SUPER_ADMIN"
    case admin = "ADMIN"
    case cashier = "CASHIER"
    case customer = "CUSTOMER"
}

struct User: Codable, Identifiable {
    var id: String { email } // Using email as the unique identifier
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
