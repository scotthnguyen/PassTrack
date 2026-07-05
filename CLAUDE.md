# PassTrack

Accessibility-first credential manager built for the Apple portfolio / interview demo. Targets iOS 26 with Swift 6 strict concurrency from day one.

## Architecture

Three targets linked through a shared framework:

| Target | Type | Purpose |
|---|---|---|
| `PassTrackKit` | Framework | Models, crypto, store, auth — single source of truth |
| `PassTrack` | App | Main vault UI, App Intents, Settings |
| `PassTrackAutoFill` | App Extension | AutoFill Credential Provider for passwords, passkeys, TOTP |
| `PassTrackKitTests` | Unit Tests | Crypto and store logic |

**App Group:** `group.com.scottnguyen.passtrack` (shared store + Keychain between app and extension)

## Security model

```
Passphrase → HKDF-SHA256 → wrapping key → AES-GCM → data key (in memory only when unlocked)
Biometrics → Keychain (kSecAccessControlBiometryAny) → data key
Data key → AES-GCM → SwiftData store + CloudKit records (ciphertext only)
```

Key rules:
- Passphrase never stored — only salt + HKDF-derived wrapped key
- Data key lives in memory only; cleared on lock
- CloudKit syncs ciphertext only — zero-knowledge

## Build

```bash
# Generate the Xcode project (run after editing project.yml)
xcodegen generate

# Open in Xcode
open PassTrack.xcodeproj

# Run tests (requires Xcode)
xcodebuild test -project PassTrack.xcodeproj -scheme PassTrackKitTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

## Key files

| File | Role |
|---|---|
| `project.yml` | xcodegen project definition — edit this, not `.xcodeproj` directly |
| `PassTrackKit/Sources/Crypto/VaultCrypto.swift` | AES-GCM encrypt/decrypt |
| `PassTrackKit/Sources/Crypto/SecureEnclaveKey.swift` | Secure Enclave key wrapping |
| `PassTrackKit/Sources/Crypto/KeyDerivation.swift` | HKDF passphrase → symmetric key |
| `PassTrackKit/Sources/Store/VaultStore.swift` | SwiftData container, CRUD, lock state |
| `PassTrackKit/Sources/Auth/BiometricAuth.swift` | LAContext + Keychain unlock flows |
| `PassTrackAutoFill/Sources/CredentialProviderViewController.swift` | AutoFill extension entry point |

## Conventions

- **Swift 6, strict concurrency on.** Every new file must compile without concurrency warnings.
- `@Observable` (not `ObservableObject`) for all view models.
- `@MainActor` on `VaultStore` and any type that touches `ModelContext`.
- `public` access on all PassTrackKit types (needed by the extension and app).
- No comments unless the WHY is non-obvious. No multi-line docstrings.
- Swift Testing (`@Test`, `#expect`) for all new tests — no XCTest.
- Accessibility labels and hints on every interactive element. VoiceOver is a QA surface, not an afterthought.

## AutoFill extension gotchas

- `ProvidesPasskeys: YES` in `PassTrackAutoFill/Info.plist` — without this iOS never offers PassTrack as a passkey provider.
- The extension re-unlocks independently; it shares no runtime state with the main app.
- `NSExtensionPrincipalClass` must be `$(PRODUCT_MODULE_NAME).CredentialProviderViewController`.
- Keep the extension memory footprint tiny — the system will kill heavy extensions.

## Deep link scheme

`passtrack://credential/<uuid>` — opens the app to a specific credential detail view.
If locked, the lock screen is shown first and navigation happens after unlock.

---

## Step-by-step build plan

### Phase 0 — Foundations ✅
> Goal: encrypted credential survives a lock/unlock cycle.

- [x] Xcode project with 3 targets (PassTrackKit, PassTrack, PassTrackAutoFill)
- [x] SwiftData models: `Credential`, `Passkey`, `SecureNote`, `Tag`, `AuditRecord`
- [x] Crypto layer: `VaultCrypto` (AES-GCM), `KeyDerivation` (HKDF-SHA256), `SecureEnclaveKey`
- [x] `VaultStore` — SwiftData container, CRUD, in-memory data key, lock/unlock state
- [x] `BiometricAuth` — Face ID unlock + passphrase fallback, both backed by Keychain
- [x] Swift Testing suite: `VaultCryptoTests`, `KeyDerivationTests`, `PasswordGeneratorTests`
- [ ] **Milestone:** Install Xcode, run the app on simulator, add a credential, lock, unlock with Face ID, read it back. Run tests and confirm all pass.

---

### Phase 1 — Core vault UI + accessibility
> Goal: a blind user can navigate the entire app with VoiceOver without hitting a dead end.

- [ ] Audit every view for missing `accessibilityLabel` / `accessibilityHint`
- [ ] Verify reading order by swiping through each screen with VoiceOver (eyes closed)
- [ ] Add `accessibilityRotor` entries on `VaultListView` for Logins, Passkeys, and Passkeys categories
- [ ] Test Dynamic Type at `xxxLarge` — no clipping, no truncation
- [ ] Apply Liquid Glass materials (`.glassEffect()`) to cards and the tab bar
- [ ] Respect `UIAccessibility.isReduceMotionEnabled` for all animations
- [ ] Clipboard auto-clear: confirm the VoiceOver announcement fires ("Password copied. Clears in 30s.")
- [ ] **Milestone:** Record a VoiceOver walkthrough of the full app with zero unlabeled elements.

---

### Phase 2 — AutoFill Credential Provider extension
> Goal: fill a password into a third-party app using PassTrack from the QuickType bar.

**Setup (do this first in Xcode):**
- [ ] Sign in with Apple ID in Xcode → Signing & Capabilities
- [ ] Enable App Group (`group.com.scottnguyen.passtrack`) on all 3 targets
- [ ] Enable Keychain Sharing on all 3 targets
- [ ] Enable AutoFill Credential Provider capability on `PassTrackAutoFill`
- [ ] On device: Settings → Passwords → AutoFill Passwords → enable PassTrack

**Code:**
- [ ] Verify `CredentialProviderViewController` presents `AutoFillVaultView` correctly
- [ ] Test password fill flow end-to-end in a real third-party app (e.g. a test login page)
- [ ] Confirm the extension re-unlocks independently (it has no shared runtime state with the app)
- [ ] Keep extension memory usage minimal — no heavy SwiftUI views or preloading
- [ ] **Milestone:** Open any app with a login screen → PassTrack appears in QuickType bar → select a credential → fields are filled.

---

### Phase 3 — Passkeys + TOTP
> Goal: create and sign in with a passkey stored in PassTrack.

**Passkeys:**
- [ ] Confirm `ProvidesPasskeys: YES` is in `PassTrackAutoFill/Info.plist` (already set)
- [ ] Test `prepareInterfaceForPasskeyRegistration` on a passkey-capable site (e.g. `demo.passkey.org`)
- [ ] Test `prepareInterfaceToProvideCredential` assertion flow (sign in with existing passkey)
- [ ] Verify private key is stored in Keychain as `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- [ ] Verify `Passkey` model is saved to the SwiftData store and shows in `VaultListView`

**TOTP:**
- [ ] Scan a QR code (or paste a secret) to set up TOTP on a credential
- [ ] Confirm `TOTPGenerator.generate()` produces the correct 6-digit code (compare against Google Authenticator)
- [ ] Confirm the countdown ring in `CredentialDetailView` updates every second
- [ ] Wire `ASOneTimeCodeCredential` in the extension for TOTP AutoFill
- [ ] **Milestone:** Create a passkey on `demo.passkey.org`, sign out, sign back in using the passkey from PassTrack.

---

### Phase 4 — CloudKit encrypted sync
> Goal: a credential created on one device appears on a second device; CloudKit dashboard shows only ciphertext.

**Setup:**
- [ ] Enable iCloud + CloudKit capability on the `PassTrack` target in Xcode
- [ ] Create the CloudKit container `iCloud.com.scottnguyen.passtrack` in the Apple Developer portal
- [ ] Sign into the same iCloud test account on two simulators

**Code:**
- [ ] Verify `ModelConfiguration(cloudKitDatabase: .private(...))` is wiring correctly (no errors in console)
- [ ] Create a credential on simulator A → confirm it appears on simulator B within ~30s
- [ ] Open CloudKit Console → confirm all record fields are opaque `Data` blobs (no plaintext)
- [ ] Test offline edits: create on A while B is offline → bring B online → confirm sync resolves correctly
- [ ] Document the conflict resolution strategy (last-write-wins on `updatedAt`) in a comment in `VaultStore`
- [ ] Note: passkey private keys are intentionally device-local and do NOT sync — only `Passkey` metadata syncs
- [ ] **Milestone:** CloudKit Console record viewer shows zero readable strings in sensitive fields.

---

### Phase 5 — Voice retrieval (App Intents / Siri)
> Goal: "Hey Siri, get my Netflix login from PassTrack" opens the app to that credential.

- [ ] Test `RetrieveCredentialIntent` — say the trigger phrase, confirm Siri resolves the entity and opens the detail view
- [ ] Test `GeneratePasswordIntent` from the Shortcuts app — confirm it returns a usable password string
- [ ] Verify `PassTrackShortcuts` phrases appear in Settings → Siri & Search → PassTrack
- [ ] Test Spotlight: search for a credential title → result appears → tap → navigates to detail view
- [ ] Test the deep link handler: `passtrack://credential/<uuid>` navigates correctly when locked (shows lock screen first) and when unlocked
- [ ] **Milestone:** App is closed. Say "Hey Siri, get my Netflix login from PassTrack." App opens to the Netflix credential.

---

### Phase 6 — Accessibility audit + release prep
> Goal: ship-ready build with full test coverage and a clean App Store submission.

- [ ] Full VoiceOver pass on every screen: labels, hints, reading order, focus after actions
- [ ] Dynamic Type `xxxLarge` on every screen — no clipping
- [ ] Assistive Access mode — core flows (unlock, view credential, copy password) still work
- [ ] Confirm clipboard auto-clear and the VoiceOver announcement on all copy actions
- [ ] Confirm Reduced Motion disables/softens all animations
- [ ] Swift Testing: add `VaultStoreTests` covering lock/unlock state and CRUD
- [ ] Set up Xcode Cloud: build + test on every push to `main`
- [ ] String Catalog localization pass (add `Localizable.xcstrings`)
- [ ] TipKit: add contextual tip for first-time AutoFill setup
- [ ] Write README: architecture diagram, security/threat model, accessibility statement
- [ ] App Store assets: screenshots (including one with VoiceOver visible), privacy nutrition label
- [ ] **Milestone:** Submit to App Store review.
