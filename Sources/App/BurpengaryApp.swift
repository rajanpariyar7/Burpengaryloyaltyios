import SwiftUI
import FirebaseCore

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
            if viewModel.currentUser != nil {
                MainTabView(viewModel: viewModel)
            } else {
                LoginView(viewModel: viewModel)
            }
        }
    }
}
