# Burpengary Loyalty — iOS (native SwiftUI)

Native SwiftUI port of the Burpengary Market Loyalty app
(`com.burpengaryfruitmarket.loyalty`), built against the same Firebase project
and Firestore schema as the Android client
(`Burpengary-android-native-final`).

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen), so there is
no `.xcodeproj` in the repo — `project.yml` describes the target and
`xcodegen generate` recreates the project (Codemagic runs this automatically per
`codemagic.yaml`).

## Features

Routing is role based, exactly like the Android `MainActivity`:

| Role | Experience |
| --- | --- |
| `CUSTOMER` | Home, ID, Catalog, History, Profile |
| `CASHIER` | Scan/register, History |
| `ADMIN` | Dashboard, Offers, Transactions, Customers, Settings |
| `SUPER_ADMIN` | Config, Roles, Transactions, Audit logs |

- Email/password login, signup (5 bonus points), password reset, Google Sign-In
- Digital membership card with QR code and Code 128 barcode (Core Image)
- Points balance, reward value, 10-slot digital punch card
- Offers catalog with categories and voucher redemption
- Point transaction history
- Cashier register: customer search, camera scanning (AVFoundation), purchase →
  points, stamps, and point redemption at the till
- Admin: store stats, offer/category CRUD, customer database, loyalty settings,
  cashier creation and cashier login window
- Super admin: global loyalty rules, role management, audit trail
- Local + Firebase Cloud Messaging notifications (`promotions` topic)

## Firestore schema

`users/{email}`, `rewards`, `offers`, `categories`, `transactions`,
`auditLogs`, `settings/main` — field names match the Android data classes.
Boolean `Reward.isRedeemed` is stored as `redeemed`, which is how the Android
Firestore mapper serializes it.

Defaults: 10 points per $1, $1.00 discount per 100 points, 100 point redemption
threshold.

Balance changes (points, stamps, redemptions) run inside Firestore transactions
and only write balance fields, so two registers cannot overwrite each other.
Passwords live in Firebase Auth only — members choose their own at signup and
change it with reauthentication; no password is stored in Firestore.

## Security rules

`firestore.rules` holds the rules that enforce the role model server side; the
in-app role checks are a UX guard only. Deploy them with:

```bash
firebase deploy --only firestore:rules
```

## Building

1. `brew install xcodegen`
2. `xcodegen generate`
3. `open BurpengaryLoyalty.xcodeproj`

`Resources/GoogleService-Info.plist` is already the Firebase iOS config for
`burpengary-fruit-market`. Codemagic builds and ships the IPA to TestFlight via
`codemagic.yaml`.

### Push notifications

Remote notifications are wired through FirebaseMessaging, but the app is not
built with an `aps-environment` entitlement — add the Push Notifications
capability to the App ID/provisioning profile and an entitlements file before
relying on remote pushes. Local notifications work without it.
