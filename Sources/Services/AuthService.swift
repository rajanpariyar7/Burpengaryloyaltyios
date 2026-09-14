import Foundation
import FirebaseAuth
import GoogleSignIn
import UIKit

enum AuthError: LocalizedError {
    case notAuthenticated
    case tokenFetchFailed
    case noPresentingViewController
    case googleTokenMissing

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You're not signed in."
        case .tokenFetchFailed: return "Could not verify your session. Please sign in again."
        case .noPresentingViewController: return "Couldn't start Google Sign-In. Please try again."
        case .googleTokenMissing: return "Google Sign-In didn't return a valid token."
        }
    }
}

/// Thin wrapper around FirebaseAuth so the rest of the app never talks to
/// the SDK directly (mirrors having a single AuthRepository on the Android side).
final class AuthService {

    static let shared = AuthService()
    private init() {}

    var currentFirebaseUser: FirebaseAuth.User? {
        Auth.auth().currentUser
    }

    func signIn(email: String, password: String) async throws -> FirebaseAuth.User {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return result.user
    }

    func signUp(name: String, email: String, password: String) async throws -> FirebaseAuth.User {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = name
        try await changeRequest.commitChanges()
        return result.user
    }

    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    /// Matches Android's `loginWithGoogle`: presents the Google account
    /// picker, then exchanges the Google credential for a Firebase session.
    @MainActor
    func signInWithGoogle() async throws -> FirebaseAuth.User {
        guard let presenting = UIApplication.topViewController() else {
            throw AuthError.noPresentingViewController
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.googleTokenMissing
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        let authResult = try await Auth.auth().signIn(with: credential)
        return authResult.user
    }

    /// ID token sent as a Bearer token to the Laravel backend so it can
    /// verify the Firebase user and look up their role / loyalty record.
    func fetchIDToken() async throws -> String {
        guard let user = Auth.auth().currentUser else { throw AuthError.notAuthenticated }
        do {
            return try await user.getIDToken()
        } catch {
            throw AuthError.tokenFetchFailed
        }
    }
}
