# Upload instructions

This zip mirrors your repo's real layout (`Sources/App`, `Sources/Models`,
`Sources/ViewModels`, `Sources/Views`) instead of a flat `Sources/` folder.

## 1. Delete the stray root-level copies first
Your last screenshots showed these sitting at the repo ROOT (outside
`Sources/`), which is why XcodeGen never picked them up:
`AdminHomeView.swift`, `AdminNotificationsView.swift`,
`AdminOffersView.swift`, `AdminRolesView.swift`, `BurpengaryApp.swift`,
`CustomerDashboardScreen.swift`, `GetInTouchView.swift`, `LoginView.swift`,
`LoyaltyViewModel.swift`, `Models.swift`, `ProfileView.swift`,
`RewardsView.swift`. Delete all of those from the repo root — `firestore/`,
`functions/`, and `project.yml` at the root are correctly placed and don't
need touching.

## 2. Upload this zip's contents into the matching folders
- `Sources/App/BurpengaryApp.swift` → your `Sources/App/`
- `Sources/Models/Models.swift` → your `Sources/Models/`
- `Sources/ViewModels/LoyaltyViewModel.swift` → your `Sources/ViewModels/`
- `Sources/Views/*.swift` (9 files) → your `Sources/Views/`
- `project.yml` → repo root (replace yours — this is the one with the
  `name: BurpengaryLoyalty` fix)
- `firestore/firestore.rules`, `functions/index.js` → repo root, same spots
  they're already in

I did NOT touch `codemagic.yaml` — you've edited it since I last saw it
("Refactor codemagic.yaml for script indentation"), so I'd rather not
overwrite it blindly.

## 3. Still unresolved: I don't have your existing Views yet
`Sources/Views/` already has `MainTabView.swift`, `HomeView.swift`,
`AdminView.swift`, `SuperAdminView.swift`, `CashierView.swift`,
`StaffToolsView.swift`, `BarcodeScannerView.swift`, `OffersView.swift`,
`SignUpView.swift` — none of which I've ever seen. This zip's
`AdminHomeView.swift` / `AdminOffersView.swift` / `AdminNotificationsView.swift`
/ `AdminRolesView.swift` and the role-routing in `BurpengaryApp.swift` were
written without knowing what's in those files, so there is a real chance of
duplication or naming collisions (e.g. if `MainTabView.swift` already does
what my `BurpengaryApp.swift` role-switch does, or `AdminView.swift`
already has an offers screen).

**This zip will very likely still fail to build** until those are
reconciled. Uploading the 9 files listed above (or the whole current
`Sources/Views/` folder) so I can check for overlaps is the next step —
happy to do that pass as soon as I can see them.
