import SwiftUI
import FirebaseCore
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }

  func application(_ app: UIApplication,
                    open url: URL,
                    options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    GIDSignIn.sharedInstance.handle(url)
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
                    MainTabView(viewModel: viewModel)
                } else {
                    LoginView(viewModel: viewModel)
                }
            }
            // App-wide: match the Android app's light theme regardless of
            // the device's system Dark Mode setting.
            .preferredColorScheme(.light)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
