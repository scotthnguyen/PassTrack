import CryptoKit
import PassTrackKit
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppModel {
    let store: VaultStore = .shared

    var needsOnboarding: Bool = !BiometricAuth.isSetUp
    var pendingRecoveryCode: String?
    var needsPassphraseReset = false
    var pendingDeepLink: URL?
    var autoLockInterval: TimeInterval = 60
    var clipboardTimeout: TimeInterval = 30

    private var lockTask: Task<Void, Never>?

    var isLocked: Bool { store.isLocked }

    // MARK: - Lock management

    func unlockWithBiometrics() async {
        do {
            let key = try await BiometricAuth.unlockWithBiometrics()
            store.unlock(with: key)
            scheduleAutoLock()
        } catch {
            // Errors surface in the lock screen view via thrown errors
        }
    }

    func unlock(passphrase: String) throws {
        let key = try BiometricAuth.unlock(passphrase: passphrase)
        store.unlock(with: key)
        scheduleAutoLock()
    }

    func unlock(recoveryCode: String) throws {
        let key = try BiometricAuth.unlock(recoveryCode: recoveryCode)
        store.unlock(with: key)
        needsPassphraseReset = true
        scheduleAutoLock()
    }

    func setupVault(passphrase: String) throws {
        let result = try BiometricAuth.setup(passphrase: passphrase)
        store.unlock(with: result.dataKey)
        pendingRecoveryCode = result.recoveryCode
        // needsOnboarding stays true until user acknowledges the recovery code
    }

    func acknowledgeRecoveryCode() {
        pendingRecoveryCode = nil
        needsOnboarding = false
        scheduleAutoLock()
    }

    func lock() {
        store.lock()
        lockTask?.cancel()
    }

    func resetAutoLockTimer() {
        scheduleAutoLock()
    }

    // MARK: - Deep links

    func handle(deepLink url: URL) {
        guard url.scheme == "passtrack" else { return }
        if store.isLocked {
            pendingDeepLink = url
        } else {
            navigate(to: url)
        }
    }

    func resolvePendingDeepLink() {
        guard let url = pendingDeepLink else { return }
        pendingDeepLink = nil
        navigate(to: url)
    }

    private func navigate(to url: URL) {
        NotificationCenter.default.post(name: .deepLinkReceived, object: url)
    }

    // MARK: - Auto-lock

    private func scheduleAutoLock() {
        lockTask?.cancel()
        let interval = autoLockInterval
        lockTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.lock() }
        }
    }
}

extension Notification.Name {
    static let deepLinkReceived = Notification.Name("com.scottnguyen.passtrack.deepLinkReceived")
}
