# PassTrack 2.0

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

## Phase roadmap

| Phase | Status | Milestone |
|---|---|---|
| 0 — Foundations | In progress | Encrypted credential survives lock/unlock |
| 1 — Vault UI + Accessibility | Pending | Blind VoiceOver pass on every screen |
| 2 — AutoFill extension | Pending | Fill password in a third-party app |
| 3 — Passkeys + TOTP | Pending | Create and sign in with passkey |
| 4 — CloudKit sync | Pending | Credential appears on second device |
| 5 — Voice / App Intents | Pending | Siri retrieves credential by voice |
| 6 — Audit + release | Pending | TestFlight + App Store submission |

## AutoFill extension gotchas

- `ProvidesPasskeys: YES` in `PassTrackAutoFill/Info.plist` — without this iOS never offers PassTrack as a passkey provider.
- The extension re-unlocks independently; it shares no runtime state with the main app.
- `NSExtensionPrincipalClass` must be `$(PRODUCT_MODULE_NAME).CredentialProviderViewController`.
- Keep the extension memory footprint tiny — the system will kill heavy extensions.

## Deep link scheme

`passtrack://credential/<uuid>` — opens the app to a specific credential detail view.
If locked, the lock screen is shown first and navigation happens after unlock.
