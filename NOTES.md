# What was wrong & what I changed

## 1. Dark screen on login (TestFlight build)
LoginView had no background color and no forced color scheme, so it just
inherited the phone's system Dark Mode setting — on a device in dark mode,
`Color(UIColor.systemBackground)` renders black, which is the "black and
green" screen you saw. The Android app forces its own light theme, so it
never does this.
Fix: `.preferredColorScheme(.light)` on the root app scene + LoginView, and
an explicit white background.

## 2. Login "not working"
Two causes, both silent failures:
- `viewModel.errorMessage` / `successMessage` were never displayed anywhere
  in LoginView, so any failed sign-in (wrong password, malformed email,
  etc.) just did nothing visible.
- The field is labeled "Username or Email" but `login()` always calls
  `Auth.auth().signIn(withEmail:)`, which requires a real email address.
  If you type a bare username, Firebase rejects it immediately — silently,
  because of the point above.
Fix: error/success banners now render on the login screen. If you actually
need username-based login (not just email), that requires a Firestore
lookup to resolve username -> email before calling signIn(withEmail:) —
I did not add that since I don't know if Android supports it; say the word
and I'll wire it in.

## 3. Missing "Sign in with Google" and Sign Up
The Android screenshots show both; the iOS skeleton had neither, even
though `GoogleService-Info.plist` and the `GoogleSignIn` package were
already wired into project.yml. Added:
- `signInWithGoogle()` in LoyaltyViewModel (creates the Firestore user doc
  on first Google sign-in, mirroring the email signup flow).
- Google Sign-In button + Sign Up sheet on LoginView.
- New `SignUpView.swift` matching the Android Full Name / Email / Phone
  Number form.
- `BurpengaryApp.swift` updated to route the Google Sign-In callback URL
  (the scheme was already declared in project.yml).

## How to apply
Drop these 4 files into your existing project, replacing the originals at:
- Sources/App/BurpengaryApp.swift
- Sources/Views/LoginView.swift
- Sources/ViewModels/LoyaltyViewModel.swift
- Sources/Views/SignUpView.swift  (new file)

Then commit + push, and let Codemagic build from project.yml as usual
(no changes needed there — GoogleSignIn was already declared).
