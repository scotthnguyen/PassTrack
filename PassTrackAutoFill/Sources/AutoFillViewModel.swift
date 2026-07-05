import AuthenticationServices
import PassTrackKit
import Foundation
import Observation

@MainActor
@Observable
final class AutoFillViewModel {
    let store: VaultStore
    private let serviceIdentifiers: [ASCredentialServiceIdentifier]

    private(set) var credentials: [Credential] = []
    private(set) var isLocked: Bool = true
    private(set) var isLoading = false

    init(store: VaultStore, serviceIdentifiers: [ASCredentialServiceIdentifier] = []) {
        self.store = store
        self.serviceIdentifiers = serviceIdentifiers
        self.isLocked = store.isLocked
    }

    convenience init(store: VaultStore, credentialIdentity: any ASCredentialIdentity) {
        let serviceID = ASCredentialServiceIdentifier(
            identifier: credentialIdentity.serviceIdentifier.identifier,
            type: credentialIdentity.serviceIdentifier.type
        )
        self.init(store: store, serviceIdentifiers: [serviceID])
    }

    func unlockWithBiometrics() async {
        do {
            let key = try await BiometricAuth.unlockWithBiometrics(reason: "Unlock to fill your credential")
            store.unlock(with: key)
            isLocked = false
            await loadCredentials()
        } catch {
            // Lock screen will display the error
        }
    }

    func loadCredentials() async {
        isLoading = true
        defer { isLoading = false }

        let hostnames = serviceIdentifiers.compactMap { identifier -> String? in
            guard identifier.type == .URL,
                  let url = URL(string: identifier.identifier),
                  let host = url.host else { return identifier.identifier }
            return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        }

        do {
            let all = try store.fetchCredentials()
            if hostnames.isEmpty {
                credentials = all
            } else {
                credentials = all.filter { credential in
                    guard let domain = credential.hostDomain else { return false }
                    return hostnames.contains { hostname in
                        domain == hostname || domain.hasSuffix("." + hostname) || hostname.hasSuffix("." + domain)
                    }
                }
                // Show all credentials if no matches
                if credentials.isEmpty { credentials = all }
            }
        } catch {
            credentials = []
        }
    }
}
