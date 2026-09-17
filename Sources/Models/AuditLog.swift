import Foundation

struct AuditLog: Codable, Identifiable {
    var id: String = ""
    var action: String = ""
    var changedBy: String = ""
    var timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
}
func redeemPoints(email: String, amount: Int, completion: @escaping (Bool, String?) -> Void) {
    let userRef = Firestore.firestore().collection("users").document(email)

    Firestore.firestore().runTransaction({ (transaction, errorPointer) -> Any? in
        let snapshot: DocumentSnapshot
        do {
            snapshot = try transaction.getDocument(userRef)
        } catch {
            errorPointer?.pointee = error as NSError
            return nil
        }

        let currentPoints = snapshot.data()?["points"] as? Int ?? 0
        guard currentPoints >= amount else {
            errorPointer?.pointee = NSError(
                domain: "Redemption", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Insufficient points"]
            )
            return nil
        }

        transaction.updateData(["points": currentPoints - amount], forDocument: userRef)
        return nil
    }) { _, error in
        completion(error == nil, error?.localizedDescription)
    }
}
transaction.updateData(["points": FieldValue.increment(Int64(amount))], forDocument: userRef)
