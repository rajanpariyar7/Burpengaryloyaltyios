import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class LoyaltyViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private var db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            guard let self = self else { return }
            if let user = user, let email = user.email {
                self.fetchUserData(email: email)
            } else {
                self.currentUser = nil
            }
        }
    }
    
    func login(email: String, pass: String) {
        guard !email.isEmpty, !pass.isEmpty else {
            self.errorMessage = "Email and Password required"
            return
        }
        
        Auth.auth().signIn(withEmail: email, password: pass) { [weak self] result, error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
                return
            }
            self?.successMessage = "Logged in successfully"
        }
    }
    
    func signup(emailOrPhone: String, phoneOptional: String, name: String) {
        let identifier = emailOrPhone.isEmpty ? phoneOptional : emailOrPhone
        guard !identifier.isEmpty else {
            self.errorMessage = "Email or Phone required"
            return
        }
        
        let defaultPassword = String(identifier.prefix(4)) + "1234"
        
        Auth.auth().createUser(withEmail: identifier, password: defaultPassword) { [weak self] result, error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
                return
            }
            
            let newUser = User(
                email: identifier,
                passwordHash: defaultPassword,
                name: name,
                role: .customer,
                points: 5 // Bonus points!
            )
            
            do {
                try self?.db.collection("users").document(identifier).setData(from: newUser)
                self?.successMessage = "Account created! 5 bonus points awarded."
            } catch {
                self?.errorMessage = "Failed to save user data."
            }
        }
    }
    
    func resetPassword(email: String) {
        guard !email.isEmpty else {
            self.errorMessage = "Please enter your email to reset password"
            return
        }
        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
            } else {
                self?.successMessage = "Password reset email sent"
            }
        }
    }
    
    func logout() {
        do {
            try Auth.auth().signOut()
            self.currentUser = nil
        } catch {
            self.errorMessage = "Failed to logout"
        }
    }
    
    private func fetchUserData(email: String) {
        db.collection("users").document(email).addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                print("Error fetching user: \(error)")
                return
            }
            do {
                self?.currentUser = try snapshot?.data(as: User.self)
            } catch {
                print("Error decoding user: \(error)")
            }
        }
    }
}
