import SwiftUI
import FirebaseCore
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}

@main
struct BurpengaryApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var viewModel = LoyaltyViewModel()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if viewModel.currentUser != nil {
                    // Customer / Cashier Dashboard
                    Text("Dashboard")
                } else {
                    LoginView(viewModel: viewModel)
                }
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
