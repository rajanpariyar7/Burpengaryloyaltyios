import SwiftUI
import FirebaseCore
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }

  // Added: hook point for push notifications. To actually receive the
  // AppNotification pushes the Cloud Function sends, you'll also need to:
  //   1. Add the Push Notifications capability + a provisioning profile that
  //      includes it (Codemagic: set via your signing profile).
  //   2. import FirebaseMessaging, set Messaging.messaging().delegate = self
  //      somewhere (e.g. in application(_:didFinishLaunchingWithOptions:)),
  //      conform AppDelegate to MessagingDelegate, and in
  //      messaging(_:didReceiveRegistrationToken:) call
  //      viewModel.updateFCMToken(token) so the token in Firestore stays current.
  //   3. Call UNUserNotificationCenter.current().requestAuthorization(...) and
  //      application.registerForRemoteNotifications() to prompt the user.
  // Left out of this file since it needs a reference to the shared
  // LoyaltyViewModel instance, which isn't available at AppDelegate scope
  // without extra plumbing — happy to wire it in if you want push working
  // end-to-end.
}

@main
struct BurpengaryApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var viewModel = LoyaltyViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if let user = viewModel.currentUser {
                    switch user.role {
                    case .customer:
                        CustomerDashboardScreen(viewModel: viewModel)
                    case .cashier, .admin, .superAdmin:
                        AdminHomeView(viewModel: viewModel)
                    }
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
