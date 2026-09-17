# What changed this round

Cross-checked every `viewModel.` reference in SuperAdminView.swift and
AdminView.swift against LoyaltyViewModel.swift. Everything below was
referenced by the views but didn't exist in the view model - that's the
root cause of every error you've hit so far, not just `allTransactions`.

## Added to LoyaltyViewModel.swift

**Published data:**
- `offers: [Offer]`, `categories: [Category]`, `pointSettings: PointSettings?`
  — public catalog data, listeners start automatically in `init()`.
- `allUsers: [User]`, `allTransactions: [PointTransaction]`
  — staff-only data, listeners do NOT start automatically.
- `allCustomers: [User]` — computed from `allUsers` (filtered to `.customer`
  role), not a separate Firestore listener.

**Action needed:** add this to `AdminView` and `SuperAdminView`'s top-level
`body` (not inside each tab - once per view is enough):
```swift
.onAppear { viewModel.listenToAdminData() }
```
This replaces the standalone `viewModel.listenToAuditLogs()` call I told you
to add earlier — `listenToAdminData()` calls it internally along with the
new `allUsers`/`allTransactions` listeners, so you only need the one call now.

**Functions added**, matching the exact signatures/argument labels your
views already call:
- `updateSettings(pointsPerDollar:discountPer100Points:redemptionThreshold:adminWriteEnabled:cashierLoginEnabled:cashierLoginStartTime:cashierLoginEndTime:)`
- `changeUserRole(email:newRole:)`
- `createCashier(email:name:pass:)`
- `addOffer(title:price:description:category:imageUrl:)`
- `deleteOffer(_:)`
- `addCategory(_:)`
- `deleteCategory(_:)`

## Two real bugs fixed along the way

1. **`AuditLog`/`PointTransaction` had `var id: String = ""` instead of
   `@DocumentID var id: String?`.** Every document decoded from Firestore
   would get the *same* empty-string id, which breaks SwiftUI `List`
   identity — your audit log and transaction screens would have rendered
   incorrectly (missing/duplicate rows) even once they had real data.
   Fixed in `Models.swift`. This also required adding
   `import FirebaseFirestore` to `Models.swift` (it only had `Foundation`
   before) — `@DocumentID` lives in that module.

2. **`createCashier` would have signed the admin out.** Creating a Firebase
   Auth account with the default `Auth.auth()` instance signs the *client*
   in as that new account. So an admin creating a cashier would have been
   immediately booted into the cashier's session. Fixed by minting the
   account on a secondary `FirebaseApp`/`Auth` instance, then signing that
   instance back out — the admin's own session is never touched.

## Also wired up (needed for the Admin Stats tab to show real numbers)

`redeemPoints` and `addPoints` now also write a `PointTransaction` document
(in addition to the audit log entry they already wrote). Without this,
`AdminStatsTab`'s "Points Issued Today" / "Points Redeemed Today" and
`AdminTransactionsTab`'s ledger would always be empty, since nothing was
ever populating the `transactions` collection.

## Not touched / still open

- `signup()` still stores a derived password in Firestore as plaintext
  (`passwordHash`). Flagging again since it's the same class of issue as
  before - not fixed here, wasn't part of this round's scope.
- The Android side still needs the matching transaction/increment pattern
  for `redeemReward`/`addPoints` for the cross-platform sync fix to hold
  end-to-end. Still waiting on `LoyaltyRepository.kt` for that.
- I have not seen `OffersView.swift`/`RewardsView.swift` (customer-facing
  catalog browsing). If either of those files *already* declares its own
  `offers`/`categories` properties or listeners, you may get a duplicate-
  declaration error on next build — if so, paste that file and I'll
  reconcile it.
