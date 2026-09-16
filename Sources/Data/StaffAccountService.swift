import FirebaseAuth
import FirebaseCore
import Foundation

/// Creates staff accounts on a secondary Firebase app so the administrator performing the
/// action keeps their own session; `Auth.createUser` signs the new account in otherwise.
enum StaffAccountService {
    private static let appName = "staffAccountCreation"

    static func createAccount(email: String, password: String) async throws {
        guard let options = FirebaseApp.app()?.options else {
            throw LoyaltyError.invalidInput("Firebase is not configured.")
        }
        if FirebaseApp.app(name: appName) == nil {
            FirebaseApp.configure(name: appName, options: options)
        }
        guard let secondaryApp = FirebaseApp.app(name: appName) else {
            throw LoyaltyError.invalidInput("Could not start a secondary Firebase session.")
        }

        let secondaryAuth = Auth.auth(app: secondaryApp)
        _ = try await secondaryAuth.createUser(withEmail: email, password: password)
        try? secondaryAuth.signOut()
    }
}
