# Burpengary Loyalty — Native iOS (SwiftUI)

Native SwiftUI counterpart to the Android app
(`Burpengary-Fruit-Market-Loyalty-android-native`), built to share the exact
same Firebase project and Firestore schema — no separate backend, and no
guessed data model. The schema below was pulled directly from the Android
repo's `LoyaltyRepository.kt` and `Entities.kt`.

## Why there's no `.xcodeproj` in this folder

Hand-writing a valid Xcode project file is fragile and normally requires Xcode's
GUI. Instead this project uses **[XcodeGen](https://github.com/yonaskolb/XcodeGen)**:
`project.yml` fully describes the app, and `xcodegen generate` produces the
`.xcodeproj` automatically. Codemagic runs this step for you on every build
(see `codemagic.yaml`) — you never need to commit or hand-edit a `.xcodeproj`.

## Project structure

```
Sources/
  App/                 App entry point, Firebase configuration
  Models/              AppUser, Reward, Offer, Role — mirror Android exactly
  Services/             AuthService (Firebase Auth), FirestoreService (Firestore)
  ViewModels/           AuthViewModel, RewardsViewModel, OffersViewModel
  Views/                LoginView, MainTabView, HomeView, RewardsView, OffersView,
                         ProfileView, StaffToolsView (role-gated: Cashier/Admin/Super Admin)
  Info.plist
Resources/               Put GoogleService-Info.plist here (see below)
project.yml              XcodeGen spec — target, bundle ID, Firebase SPM dependency
codemagic.yaml            CI: generate project → sign → build → TestFlight
```

## Firestore schema (matches Android exactly)

- **Database**: a *named* Firestore database, `burpengary-fruit-market-loyalty-database`
  — not the default `(default)` database. `FirestoreService` points at it explicitly.
- **`users/{email}`** — document ID is the user's **email**, not their Firebase
  Auth UID: `email, name, role (SUPER_ADMIN/ADMIN/CASHIER/CUSTOMER), stamps,
  points, lifetimeStamps, phone, customerId`.
- **`rewards/{id}`** — `id, title, description, costInPoints, costInStamps,
  isRedeemed, userEmail`. A reward costs stamps *or* points, never both.
- **`offers/{id}`** — `id, title, price, category, description, imageUrl`
  (no start/end dates in this schema).
- Roles other than `CUSTOMER` (`CASHIER`, `ADMIN`, `SUPER_ADMIN`) see the
  extra **Staff Tools** tab — member lookup by email, add a stamp, add points.

## Known gaps vs. the Android app (not yet ported)

- **Transactions/audit log/admin CRUD** — Android also has `PointTransaction`,
  `AuditLog`, categories management, and an all-customers list. This scaffold
  covers customer + cashier + the new login-window admin control only.
- Android's `redeemReward` doesn't use a Firestore transaction (plain
  read-then-write); the iOS version does, to avoid a race between two
  simultaneous redemptions. Functionally equivalent, just safer.

## Google Sign-In setup

1. In **Firebase Console → Authentication → Sign-in method**, make sure
   Google is enabled (it likely already is, since Android uses it).
2. After downloading `GoogleService-Info.plist` (step 1 above), open it and
   copy the `REVERSED_CLIENT_ID` value.
3. In `project.yml`, replace `REPLACE_WITH_REVERSED_CLIENT_ID` under
   `CFBundleURLTypes` with that value, then re-run `xcodegen generate`
   (Codemagic does this automatically on every build).
4. No other code changes needed — `AppDelegate.swift` configures
   `GIDSignIn` from Firebase's client ID automatically at launch.

## Cashier login window (new — not in Android yet)

Added because a cashier's login can now be turned off entirely, or
restricted to a time window (e.g. store hours), by an Admin/Super Admin:

- **`AdminSettingsView`** (visible only to Admin/Super Admin, in the "Admin"
  tab) — a toggle to disable cashier login entirely, plus start/end time
  pickers for the allowed window.
- Stored in the **same `settings/main` Firestore doc** Android already uses
  for `PointSettings`, just with two new fields
  (`cashierLoginEnabled`, `cashierLoginStartTime`, `cashierLoginEndTime`)
  added alongside the existing ones. Android's Kotlin Firestore deserializer
  ignores unknown fields, so this doesn't break the Android app — but Android
  doesn't enforce this window yet, since it has no matching code. If you want
  the same restriction enforced on Android, that needs to be added there too.
- The check runs on **every** sign-in method (email, Google) for `CASHIER`
  accounts only — Admin and Super Admin are never restricted.
- Time comparison uses a fixed `Australia/Brisbane` time zone (the store's
  location), not the phone's local time zone — change
  `AppSettings.storeTimeZone` if that assumption is wrong.

## Things you must do before the first build

1. **Register the iOS app in Firebase Console**
   Firebase Console → your project → Add app → iOS → bundle ID
   `com.burpengaryfruitmarket.loyalty`. Download the generated
   `GoogleService-Info.plist` and place it in `Resources/`. This file is
   project-specific and can't be generated for you — without it, Firebase
   will crash on launch.

2. **Create the app in App Store Connect**
   Same bundle ID as above. Note the app's Apple ID (shown in App Store
   Connect → App Information) and put it in `codemagic.yaml` under
   `APP_STORE_APPLE_ID`.

3. **Add an App Store Connect API key integration in Codemagic**
   Codemagic → Team settings → Integrations → App Store Connect → add a key
   generated from App Store Connect → Users and Access → Integrations
   (Admin or App Manager role). This is what lets Codemagic sign the build
   and upload to TestFlight without Xcode.

4. **Verify Firestore Security Rules** allow: any signed-in user to read
   `rewards`/`offers`; a user to read/write their own `users/{email}` doc
   (matched by `request.auth.token.email == email`, since docs are keyed by
   email, not UID); and staff roles (`CASHIER`/`ADMIN`/`SUPER_ADMIN`) to
   read/write other users' docs for the Staff Tools screen.

## Local development (VS Code, no Mac)

- Edit Swift files normally — you get syntax highlighting and basic
  completion but no live preview, simulator, or breakpoints without Xcode.
- Commit and push to `main` (or whatever branch you wire up in
  `codemagic.yaml`) to trigger a Codemagic build.
- Install the resulting build via **TestFlight** on your iPhone to test —
  this replaces the local simulator loop.

## Staff tools

`StaffToolsView.swift` is a placeholder shown only to `staff`/`admin` roles.
Wire it up to whatever staff-side endpoints your Laravel backend already
exposes for the Android app (e.g. scanning a member's code, awarding points).
