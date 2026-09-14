import Foundation

/// Mirrors `com.example.data.model.PointSettings` (`settings/main` doc), plus
/// new fields for cashier login control. Android's PointSettings doesn't
/// declare these extra fields, but Firestore's Kotlin deserializer ignores
/// unknown keys, so both apps can safely share this same document.
struct AppSettings: Codable {
    var id: Int = 1
    var pointsPerDollar: Int = 10
    var discountPer100Points: Double = 1.0
    var redemptionThreshold: Int = 100
    var adminWriteEnabled: Bool = true

    // New: cashier login control, managed by Admin/Super Admin.
    var cashierLoginEnabled: Bool = true
    var cashierLoginStartTime: String = "08:00" // 24h "HH:mm", store-local time
    var cashierLoginEndTime: String = "18:00"

    /// Store operating hours are treated as Brisbane local time regardless of
    /// which device/timezone the phone is in, since this gates a physical
    /// till, not the customer's own clock. Change this if that's wrong.
    static let storeTimeZone = TimeZone(identifier: "Australia/Brisbane")!

    func isWithinCashierLoginWindow(now: Date = Date()) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.storeTimeZone

        guard
            let start = Self.parseMinutes(cashierLoginStartTime),
            let end = Self.parseMinutes(cashierLoginEndTime)
        else { return true } // fail open if the stored value is malformed

        let comps = calendar.dateComponents([.hour, .minute], from: now)
        let nowMinutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)

        if start <= end {
            return nowMinutes >= start && nowMinutes <= end
        } else {
            // Window wraps past midnight (e.g. 22:00 - 02:00)
            return nowMinutes >= start || nowMinutes <= end
        }
    }

    private static func parseMinutes(_ time: String) -> Int? {
        let parts = time.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }
}
