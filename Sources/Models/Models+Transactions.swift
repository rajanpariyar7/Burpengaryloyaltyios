//
//  Models+Transactions.swift
//  Burpengary Loyalty
//
//  Additive to ios_source/Models.swift — that file has User, Reward, Offer,
//  PointSettings, but nothing for the Android app's `PointTransaction`
//  (app/src/main/java/com/example/data/model/Entities.kt), which the
//  "transactions" Firestore collection uses. Drop this file alongside
//  Models.swift, or paste this struct into Models.swift directly.
//

import Foundation

struct PointTransaction: Codable, Identifiable {
    var id: String = UUID().uuidString
    var userEmail: String = ""
    var description: String = ""
    var pointChange: Int = 0
    var timestamp: Double = Date().timeIntervalSince1970 * 1000 // matches Android's System.currentTimeMillis()
}
