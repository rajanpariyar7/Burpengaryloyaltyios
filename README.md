# Burpengary Loyalty — new features

Implements: rewards catalog with atomic/double-redeem-proof redemption,
offers & specials with image upload, admin notification composer, and
super-admin role management.

## Where things go

Drop everything under `Sources/` into your existing `Sources/` folder
(overwriting `Models.swift`, `LoyaltyViewModel.swift`, and
`BurpengaryApp.swift` — the others are new files). `LoginView.swift`,
`ProfileView.swift`, and `GetInTouchView.swift` are included unchanged, just
so the zip is drop-in complete.

- `project.yml` — replace yours; only change is adding the `FirebaseStorage`
  product (needed for offer/notification image uploads).
- `functions/index.js` — deploy separately with the Firebase CLI
  (`firebase deploy --only functions`); this is what actually sends the push
  when an admin saves a notification. Writing the Firestore doc alone does
  **not** push anything to a phone — see the comment at the top of that file
  for why.
- `firestore/firestore.rules` — deploy with `firebase deploy --only
  firestore:rules`. Backs up the client-side transaction logic (so points
  can't go negative / a reward can't be redeemed twice) with server-side
  enforcement, and restricts role changes to Super Admin.

## Fixed while I was in here

`ProfileView.swift` called `viewModel.signOut()` and
`viewModel.deleteAccount` referenced `self?.isAuthenticated` — neither
existed in the `LoyaltyViewModel.swift` you had, so it wouldn't have
compiled. Fixed: `signOut()` now exists (`logout()` still works too, as an
alias), and `deleteAccount` no longer references the undeclared property.

## Known gap: push notifications aren't fully wired end-to-end

Writing a notification in `AdminNotificationsView` → Firestore →
`functions/index.js` → FCM send is all there. What's *not* included is the
iOS side of registering for push and capturing the device token
(`Messaging.messaging().delegate`, requesting `UNUserNotificationCenter`
authorization, and calling `viewModel.updateFCMToken(token)`). That needs a
reference to the live `LoyaltyViewModel` from `AppDelegate`, which isn't
free — see the comment block in `BurpengaryApp.swift`. Say the word and
I'll wire that up too.

## Assumption on "admin must be able to give roles" vs "super admin can give roles"

Your message had both. I went with: **only Super Admin assigns
Admin/Cashier roles** (matches the Android app's convention, and is what
`AdminRolesView.swift` + the Firestore rules enforce). Everyone Admin+ can
manage Offers/Notifications. Flag it if you wanted Admins to also be able to
promote people to Admin/Cashier.
