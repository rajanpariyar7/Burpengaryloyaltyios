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

    /// Matches the Android app's staff-only screens.
    var isStaff: Bool {
        self != .customer
    }

    /// Only Admin/Super Admin manage loyalty settings and the cashier login window.
    var canManageSettings: Bool {
        self == .admin || self == .superAdmin
    }
}

/// Mirrors `com.example.data.model.User` exactly — document ID in Firestore
/// is the user's email (not their Firebase Auth UID).
struct AppUser: Codable, Identifiable {
    var id: String { email }

    var email: String = ""
    var name: String = ""
    var role: Role = .customer
    var stamps: Int = 0
    var points: Int = 0
    var lifetimeStamps: Int = 0
    var phone: String = ""
    var customerId: String = ""

    // Present in the Android schema (plaintext, stored by the existing app).
    // iOS never reads or writes this field itself — Firebase Auth handles
    // the real password. Kept only so decoding a full user doc doesn't fail.
    var passwordHash: String = ""

    enum CodingKeys: String, CodingKey {
        case email, name, role, stamps, points, lifetimeStamps, phone, customerId, passwordHash
    }
}
