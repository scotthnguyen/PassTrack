import AuthenticationServices
import CryptoKit
import PassTrackKit
import SwiftUI
import UIKit

/// Entry point for the AutoFill Credential Provider extension.
/// Handles password fill, passkey creation, and passkey assertion.
final class CredentialProviderViewController: ASCredentialProviderViewController {

    // MARK: - Password AutoFill

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        let store = VaultStore.shared
        let viewModel = AutoFillViewModel(store: store, serviceIdentifiers: serviceIdentifiers)
        presentAutoFillUI(viewModel: viewModel)
    }

    override func prepareInterfaceToProvideCredential(for credentialIdentity: any ASCredentialIdentity) {
        let store = VaultStore.shared
        let viewModel = AutoFillViewModel(store: store, credentialIdentity: credentialIdentity)
        presentAutoFillUI(viewModel: viewModel)
    }

    // MARK: - Passkey creation

    override func prepareInterfaceForPasskeyRegistration(for registrationRequest: any ASCredentialRequest) {
        guard let request = registrationRequest as? ASPasskeyCredentialRequest,
              let platformRequest = request.platformContext else {
            extensionContext.cancelRequest(withError: ASExtensionError(.failed))
            return
        }
        Task { @MainActor in
            await handlePasskeyRegistration(request: request, platformRequest: platformRequest)
        }
    }

    // MARK: - Passkey assertion

    override func prepareInterfaceToProvideCredential(for credentialRequest: any ASCredentialRequest) {
        if let passkeyRequest = credentialRequest as? ASPasskeyCredentialRequest {
            Task { @MainActor in
                await handlePasskeyAssertion(request: passkeyRequest)
            }
        } else {
            // Fall through to password path
            if let identity = credentialRequest.credentialIdentity as? ASPasswordCredentialIdentity {
                prepareInterfaceToProvideCredential(for: identity)
            }
        }
    }

    // MARK: - Private

    @MainActor
    private func presentAutoFillUI(viewModel: AutoFillViewModel) {
        let rootView = AutoFillVaultView(viewModel: viewModel) { [weak self] credential in
            guard let self else { return }
            let asCredential = ASPasswordCredential(
                user: credential.username,
                password: (try? viewModel.store.decrypt(credential.encryptedPassword)) ?? ""
            )
            extensionContext.completeRequest(withSelectedCredential: asCredential)
        } onCancel: { [weak self] in
            self?.extensionContext.cancelRequest(withError: ASExtensionError(.userCanceled))
        }

        let hostingVC = UIHostingController(rootView: rootView)
        addChild(hostingVC)
        view.addSubview(hostingVC.view)
        hostingVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hostingVC.didMove(toParent: self)
    }

    @MainActor
    private func handlePasskeyRegistration(
        request: ASPasskeyCredentialRequest,
        platformRequest: ASPasskeyRegistrationCredentialExtensionInput
    ) async {
        // Generate a P-256 key pair for the passkey.
        // The private key is stored in Keychain keyed by credentialID.
        let privateKey = P256.Signing.PrivateKey()
        let credentialID = UUID().uuidString.data(using: .utf8)!

        // Store private key in Keychain
        let keychainTag = "com.scottnguyen.passtrack.passkey.\(credentialID.base64EncodedString())"
        storePasskeyPrivateKey(privateKey.rawRepresentation, tag: keychainTag)

        // Persist the passkey metadata
        try? VaultStore.shared.addPasskey(
            relyingPartyID: request.credentialIdentity.relyingPartyIdentifier,
            relyingPartyName: nil,
            userName: request.credentialIdentity.userName,
            userHandle: request.credentialIdentity.userHandle,
            credentialID: credentialID
        )

        let registrationCredential = ASPasskeyRegistrationCredential(
            relyingParty: request.credentialIdentity.relyingPartyIdentifier,
            clientDataHash: request.clientDataHash,
            credentialID: credentialID,
            attestationObject: Data() // Simplified: none attestation
        )
        extensionContext.completeRegistrationRequest(using: registrationCredential)
    }

    @MainActor
    private func handlePasskeyAssertion(request: ASPasskeyCredentialRequest) async {
        guard let identity = request.credentialIdentity as? ASPasskeyCredentialIdentity else {
            extensionContext.cancelRequest(withError: ASExtensionError(.failed))
            return
        }

        let credentialID = identity.credentialID
        let keychainTag = "com.scottnguyen.passtrack.passkey.\(credentialID.base64EncodedString())"

        guard let privateKeyData = loadPasskeyPrivateKey(tag: keychainTag),
              let privateKey = try? P256.Signing.PrivateKey(rawRepresentation: privateKeyData) else {
            extensionContext.cancelRequest(withError: ASExtensionError(.credentialIdentityNotFound))
            return
        }

        guard let signature = try? privateKey.signature(for: request.clientDataHash) else {
            extensionContext.cancelRequest(withError: ASExtensionError(.failed))
            return
        }

        let assertionCredential = ASPasskeyAssertionCredential(
            userHandle: identity.userHandle,
            relyingParty: identity.relyingPartyIdentifier,
            signature: signature.rawRepresentation,
            clientDataHash: request.clientDataHash,
            authenticatorData: Data(),
            credentialID: credentialID
        )
        extensionContext.completeAssertionRequest(using: assertionCredential)
    }

    private func storePasskeyPrivateKey(_ keyData: Data, tag: String) {
        let query: NSDictionary = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: tag,
            kSecAttrService: "com.scottnguyen.passtrack.passkeys",
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData: keyData
        ]
        SecItemDelete(query)
        SecItemAdd(query, nil)
    }

    private func loadPasskeyPrivateKey(tag: String) -> Data? {
        let query: NSDictionary = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: tag,
            kSecAttrService: "com.scottnguyen.passtrack.passkeys",
            kSecReturnData: true
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query, &result) == errSecSuccess else { return nil }
        return result as? Data
    }
}
