import Foundation

/// Mirrors `com.example.data.model.Reward`. A reward costs either stamps OR
/// points (whichever is non-zero) — never both, per the Android repository's
/// redemption logic.
struct Reward: Codable, Identifiable {
    var id: String = ""
    var title: String = ""
    var description: String = ""
    var costInPoints: Int = 0
    var costInStamps: Int = 0
    var isRedeemed: Bool = false
    var userEmail: String? = nil

    var costDisplay: String {
        if costInStamps > 0 { return "\(costInStamps) stamps" }
        return "\(costInPoints) pts"
    }
}
