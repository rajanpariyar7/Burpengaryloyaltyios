import Foundation

/// Mirrors `com.example.data.model.Offer` exactly.
struct Offer: Codable, Identifiable {
    var id: String = ""
    var title: String = ""
    var price: String = ""
    var category: String = "General"
    var description: String = ""
    var imageUrl: String? = nil
}
