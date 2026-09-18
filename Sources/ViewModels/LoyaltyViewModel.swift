import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class LoyaltyViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var alertItem: String?
    
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
    
    // MARK: - Email/Password Login
    func login(email: String, pass: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !pass.isEmpty else {
            self.errorMessage = "Email and Password required"
            return
        }
        
        Auth.auth().signIn(withEmail: trimmedEmail, password: pass) { [weak self] result, error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
                return
            }
            guard let self = self, let userEmail = result?.user.email else { return }
            
            // Check if document exists in firestore; if not create it
            let userDoc = self.db.collection("users").document(userEmail)
            userDoc.getDocument { snapshot, _ in
                if snapshot?.exists != true {
                    let newUser = User(
                        email: userEmail,
                        name: userEmail.components(separatedBy: "@").first ?? "Customer",
                        role: .customer
                    )
                    try? userDoc.setData(from: newUser)
                }
            }
            self.successMessage = "Logged in successfully"
        }
    }
    
    // MARK: - Google Sign-In
    func loginWithGoogle(idToken: String, accessToken: String?) {
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken ?? "")
        Auth.auth().signIn(with: credential) { [weak self] result, error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
                return
            }
            guard let self = self, let user = result?.user, let email = user.email else { return }
            
            let userDoc = self.db.collection("users").document(email)
            userDoc.getDocument { snapshot, _ in
                if snapshot?.exists != true {
                    let newUser = User(
                        email: email,
                        name: user.displayName ?? (email.components(separatedBy: "@").first ?? "Customer"),
                        role: .customer,
                        points: 5 // 5 Bonus points upon signup
                    )
                    try? userDoc.setData(from: newUser)
                    self.successMessage = "Account created! 5 bonus points awarded."
                } else {
                    self.successMessage = "Logged in as \(user.displayName ?? email)"
                }
            }
        }
    }
    
    // MARK: - Signup
    func signup(emailOrPhone: String, phoneOptional: String, name: String) {
        let identifier = emailOrPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                         phoneOptional.trimmingCharacters(in: .whitespacesAndNewlines) : 
                         emailOrPhone.trimmingCharacters(in: .whitespacesAndNewlines)
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
                name: name.isEmpty ? (identifier.components(separatedBy: "@").first ?? "Customer") : name,
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
    
    // MARK: - Forgot Password
    func resetPassword(email: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            self.errorMessage = "Please enter your email to reset password"
            return
        }
        Auth.auth().sendPasswordReset(withEmail: trimmedEmail) { [weak self] error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
            } else {
                self?.successMessage = "Password reset email sent to \(trimmedEmail)"
            }
        }
    }
    
    // MARK: - Logout
    func logout() {
        do {
            try Auth.auth().signOut()
            self.currentUser = nil
        } catch {
            self.errorMessage = "Failed to logout"
        }
    }
    
    // MARK: - Atomic Double-Spend Protected Operations
    func addPoints(email: String, points: Int) async {
        guard !email.isEmpty, points != 0 else { return }
        let userRef = db.collection("users").document(email)
        try? await userRef.updateData([
            "points": FieldValue.increment(Int64(points))
        ])
    }

    func addStamp(email: String) async {
        guard !email.isEmpty else { return }
        let userRef = db.collection("users").document(email)
        try? await userRef.updateData([
            "stamps": FieldValue.increment(Int64(1)),
            "lifetimeStamps": FieldValue.increment(Int64(1))
        ])
    }

    func redeemReward(email: String, costInPoints: Int, costInStamps: Int) async -> Bool {
        guard !email.isEmpty else { return false }
        let userRef = db.collection("users").document(email)
        
        do {
            _ = try await db.runTransaction { (transaction, errorPointer) -> Any? in
                let snapshot: DocumentSnapshot
                do {
                    try snapshot = transaction.getDocument(userRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                let currentPoints = snapshot.data()?["points"] as? Int ?? 0
                let currentStamps = snapshot.data()?["stamps"] as? Int ?? 0
                
                if costInStamps > 0 {
                    if currentStamps < costInStamps {
                        let error = NSError(domain: "LoyaltyApp", code: 400, userInfo: [NSLocalizedDescriptionKey: "Insufficient stamps"])
                        errorPointer?.pointee = error
                        return nil
                    }
                    transaction.updateData(["stamps": FieldValue.increment(Int64(-costInStamps))], forDocument: userRef)
                } else if costInPoints > 0 {
                    if currentPoints < costInPoints {
                        let error = NSError(domain: "LoyaltyApp", code: 400, userInfo: [NSLocalizedDescriptionKey: "Insufficient points"])
                        errorPointer?.pointee = error
                        return nil
                    }
                    transaction.updateData(["points": FieldValue.increment(Int64(-costInPoints))], forDocument: userRef)
                }
                return true
            }
            return true
        } catch {
            return false
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

    func deleteAccount(completion: @escaping (Bool) -> Void) {
        guard let user = Auth.auth().currentUser, let email = currentUser?.email ?? user.email else {
            completion(false)
            return
        }
        
        db.collection("users").document(email).delete { [weak self] _ in
            user.delete { error in
                DispatchQueue.main.async {
                    if error == nil {
                        self?.currentUser = nil
                        self?.isAuthenticated = false
                        completion(true)
                    } else {
                        self?.signOut()
                        completion(false)
                    }
                }
            }
        }
    }
}
