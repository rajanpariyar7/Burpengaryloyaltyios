import Foundation

enum Role: String, Codable, CaseIterable {
    case superAdmin = "SUPER_ADMIN"
    case admin = "ADMIN"
    case cashier = "CASHIER"
    case customer = "CUSTOMER"

    var displayName: String {
        switch self {
        case .superAdmin: return "Super Admin"
        case .admin: return "Admin"
        case .cashier: return "Cashier"
        case .customer: return "Customer"
        }
    }
}

// users/{uid} — matches "Profile: users/{uid} doc → name, email, role, points"
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
    // Added: needed so the "notifications" feature can actually deliver an FCM
    // push. Populated by LoyaltyViewModel.registerForPushNotifications() once
    // the app has notification permission and APNs hands back a token.
    var fcmToken: String? = nil
}

// rewards/{rewardId} — the redeemable catalog (admin-managed).
// users/{email}/redeemed/{rewardId} reuses this same struct for the
// customer's redeemed copy: `redeemedAt` is set only on that copy, never
// on the catalog original, so isRedeemed()/isCatalogItem can tell them apart.
struct Reward: Codable, Identifiable {
    var id: String = UUID().uuidString
    var title: String = ""
    var description: String = ""
    var costInPoints: Int = 0
    var costInStamps: Int = 0
    var isRedeemed: Bool = false
    var userEmail: String? = nil
    // Added: set when this Reward is written into users/{email}/redeemed/{id}
    var redeemedAt: Double? = nil
}

// offers/{offerId} — everyday offers AND "specials" (a special is just an
// Offer with category == "Special" and an imageUrl pointing at an uploaded
// flyer, e.g. the Wednesday/Weekend Special banners).
struct Offer: Codable, Identifiable {
    var id: String = UUID().uuidString
    var title: String = ""
    var price: String = ""
    var category: String = "General"
    var description: String = ""
    var imageUrl: String? = nil
    // Added: who created/last edited it and when — useful for admin lists.
    var createdBy: String = ""
    var updatedAt: Double = Date().timeIntervalSince1970 * 1000
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

// notifications/{notificationId} — admin-composed announcements ("Wednesday
// Special", "Weekend Special", etc). Writing a doc here is what an admin does
// from AdminNotificationsView; ACTUALLY pushing it to devices needs the
// Cloud Function in functions/index.js (a client app cannot call the FCM
// send API directly with a server key — see that file's comment).
struct AppNotification: Codable, Identifiable {
    var id: String = UUID().uuidString
    var title: String = ""
    var message: String = ""
    var imageUrl: String? = nil
    var createdBy: String = ""
    var createdAt: Double = Date().timeIntervalSince1970 * 1000
    // Set true by the Cloud Function once FCM send has been attempted, so
    // the admin list can show "Sent" vs "Pending".
    var sent: Bool = false
}
