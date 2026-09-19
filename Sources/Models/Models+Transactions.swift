import Foundation
import FirebaseFirestore

/// One row in the points ledger (Firestore collection: "transactions").
/// `timestamp` is a Double of milliseconds since 1970 (CustomerDashboardScreen does `tx.timestamp / 1000`).
struct PointTransaction: Identifiable, Codable {
    @DocumentID var id: String?
    var userEmail: String
    var description: String
    var pointChange: Int
    var timestamp: Double

    var date: Date { Date(timeIntervalSince1970: timestamp / 1000) }
}

/// One row in the Super Admin audit trail (Firestore collection: "auditLogs").
struct AuditLog: Identifiable, Codable {
    @DocumentID var id: String?
    var action: String
    var changedBy: String
    var timestamp: Int64
}
