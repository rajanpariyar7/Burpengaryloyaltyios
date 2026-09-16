# Burpengary Loyalty — iOS (native SwiftUI)

This is a buildable Xcode/Codemagic project scaffolded around the 4 Swift files
you uploaded. It uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) so
there's no `.xcodeproj` to hand-edit or commit — `project.yml` describes the
whole target, and `xcodegen generate` builds the `.xcodeproj` fresh every time
(Codemagic runs this step automatically per `codemagic.yaml`).

## What's yours vs. what I added

**From your upload, unchanged:**
- `Sources/Models/Models.swift`
- `Sources/ViewModels/LoyaltyViewModel.swift`
- `Sources/Views/LoginView.swift`
- `Sources/App/BurpengaryApp.swift` — one change: it now routes to a real
  `MainTabView` instead of the `Text("Dashboard View goes here")` placeholder.

**Scaffolded to make it actually build and run, not verified against your
Android app's exact business logic:**
- `Sources/Views/MainTabView.swift`, `HomeView.swift`, `RewardsView.swift`,
  `OffersView.swift`, `ProfileView.swift`, `StaffToolsView.swift` — basic
  working screens (points/stamps summary, live Firestore lists for
  rewards/offers, profile + logout, staff tab gated by role). `StaffToolsView`
  is an intentional placeholder — wire it up to whatever admin/cashier actions
  your Android app supports.
- `Sources/Info.plist`, `project.yml`, `codemagic.yaml` — standard
  XcodeGen/Codemagic boilerplate, not pulled from your actual repos (I have no
  network access to fetch them), so check them against your real Android
  bundle ID / Firestore collection names before relying on them.

## Before this will actually build

1. **Bundle ID & Team ID** — edit `project.yml`, set
   `PRODUCT_BUNDLE_IDENTIFIER` and `DEVELOPMENT_TEAM`.
2. **Firebase config** — register an iOS app with that same bundle ID in the
   Firebase console (the same project your Android app uses), download
   `GoogleService-Info.plist`, and put it in `Resources/` (see the placeholder
   file there).
3. **Confirm Firestore collection/field names** — `RewardsView` and
   `OffersView` assume `rewards` and `offers` collections matching
   `Models.swift`. Double-check these against your Android app's
   `LoyaltyRepository.kt` — I generated these from your uploaded models, not
   from the Android source itself.
4. **Codemagic** — edit `codemagic.yaml`: set your real `bundle_identifier`
   and the name of your App Store Connect API key integration
   (`integrations.app_store_connect`). Push to the branch you've wired up in
   Codemagic to trigger a build.
5. Locally, if you want to open it in Xcode first: install
   [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`),
   run `xcodegen generate` in this folder, then open the generated
   `BurpengaryLoyalty.xcodeproj`.

## Note on the Android side

I don't have network access in this environment, so I can't clone or zip your
Android repo — but there's nothing to prepare there: your GitHub repo *is*
your ready-to-build source. Use GitHub's **Code → Download ZIP** on
`Burpengary-android-native-final` and open it directly in Android Studio.
