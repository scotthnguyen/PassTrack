import CryptoKit
import Foundation
import Observation
import SwiftData

public enum VaultError: Error, Sendable {
    case locked
    case decryptionFailed
    case invalidUTF8
}

@MainActor
@Observable
public final class VaultStore {
    public private(set) var isLocked = true
    public private(set) var modelContainer: ModelContainer

    private var dataKey: SymmetricKey?

    public var context: ModelContext { modelContainer.mainContext }

    public static var shared: VaultStore = {
        // Crash on misconfiguration — this is a developer error, not a user error.
        try! VaultStore()
    }()

    public init() throws {
        let schema = Schema([
            Credential.self,
            Passkey.self,
            SecureNote.self,
            Tag.self,
            AuditRecord.self
        ])
        // CloudKit sync added in Phase 4 (requires paid developer account + iCloud entitlement)
        let config = ModelConfiguration(schema: schema, url: VaultStore.storeURL)
        self.modelContainer = try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - Lock state

    public func unlock(with key: SymmetricKey) {
        dataKey = key
        isLocked = false
    }

    public func lock() {
        dataKey = nil
        isLocked = true
    }

    // MARK: - Crypto helpers (requires unlocked state)

    public func encrypt(_ string: String) throws -> Data {
        guard let key = dataKey else { throw VaultError.locked }
        return try VaultCrypto.encrypt(string, using: key)
    }

    public func decrypt(_ data: Data) throws -> String {
        guard let key = dataKey else { throw VaultError.locked }
        return try VaultCrypto.decryptString(data, using: key)
    }

    public func encryptData(_ data: Data) throws -> Data {
        guard let key = dataKey else { throw VaultError.locked }
        return try VaultCrypto.encrypt(data, using: key)
    }

    public func decryptData(_ data: Data) throws -> Data {
        guard let key = dataKey else { throw VaultError.locked }
        return try VaultCrypto.decrypt(data, using: key)
    }

    // MARK: - Vault reset

    /// Permanently deletes all vault data. Irreversible. Caller must also invoke
    /// BiometricAuth.deleteAllKeys() and reset needsOnboarding state.
    public func destroyVault() throws {
        try context.delete(model: Credential.self)
        try context.delete(model: Passkey.self)
        try context.delete(model: SecureNote.self)
        try context.delete(model: Tag.self)
        try context.delete(model: AuditRecord.self)
        try context.save()
        lock()
    }

    // MARK: - Passphrase management

    public func changePassphrase(to newPassphrase: String) throws {
        guard let key = dataKey else { throw VaultError.locked }
        try BiometricAuth.changePassphrase(currentKey: key, newPassphrase: newPassphrase)
    }

    // MARK: - Credential CRUD

    @discardableResult
    public func addCredential(
        title: String,
        username: String,
        password: String,
        websiteURL: String? = nil,
        notes: String? = nil,
        totpSecret: String? = nil,
        tags: [Tag] = []
    ) throws -> Credential {
        let encrypted = try encrypt(password)
        let credential = Credential(
            title: title,
            username: username,
            encryptedPassword: encrypted,
            websiteURL: websiteURL,
            notes: notes,
            totpSecret: totpSecret
        )
        credential.tags = tags
        context.insert(credential)
        try context.save()
        log(.credentialCreated, for: credential)
        return credential
    }

    public func updateCredential(_ credential: Credential, password: String? = nil) throws {
        if let password {
            credential.encryptedPassword = try encrypt(password)
        }
        credential.updatedAt = .now
        try context.save()
        log(.credentialUpdated, for: credential)
    }

    public func delete(_ credential: Credential) throws {
        log(.credentialDeleted, for: credential)
        context.delete(credential)
        try context.save()
    }

    public func fetchCredentials(
        matching query: String = "",
        tag: Tag? = nil,
        favoritesOnly: Bool = false
    ) throws -> [Credential] {
        var predicate: Predicate<Credential>?

        if !query.isEmpty {
            predicate = #Predicate<Credential> { c in
                c.title.localizedStandardContains(query) ||
                c.username.localizedStandardContains(query)
            }
        } else if let tag {
            let tagID = tag.id
            predicate = #Predicate<Credential> { c in
                c.tags.contains { $0.id == tagID }
            }
        } else if favoritesOnly {
            predicate = #Predicate<Credential> { $0.isFavorite }
        }

        let descriptor = FetchDescriptor<Credential>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.title)]
        )
        return try context.fetch(descriptor)
    }

    // MARK: - Passkey CRUD

    public func addPasskey(
        relyingPartyID: String,
        relyingPartyName: String?,
        userName: String,
        userHandle: Data,
        credentialID: Data
    ) throws -> Passkey {
        let passkey = Passkey(
            relyingPartyID: relyingPartyID,
            relyingPartyName: relyingPartyName,
            userName: userName,
            userHandle: userHandle,
            credentialID: credentialID
        )
        context.insert(passkey)
        try context.save()
        return passkey
    }

    public func fetchPasskeys(for relyingPartyID: String? = nil) throws -> [Passkey] {
        var predicate: Predicate<Passkey>?
        if let relyingPartyID {
            predicate = #Predicate<Passkey> { $0.relyingPartyID == relyingPartyID }
        }
        let descriptor = FetchDescriptor<Passkey>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    // MARK: - SecureNote CRUD

    @discardableResult
    public func addSecureNote(title: String, content: String) throws -> SecureNote {
        let encrypted = try encrypt(content)
        let note = SecureNote(title: title, encryptedContent: encrypted)
        context.insert(note)
        try context.save()
        return note
    }

    public func updateSecureNote(_ note: SecureNote, title: String? = nil, content: String? = nil) throws {
        if let title { note.title = title }
        if let content { note.encryptedContent = try encrypt(content) }
        note.updatedAt = .now
        try context.save()
    }

    public func delete(_ note: SecureNote) throws {
        context.delete(note)
        try context.save()
    }

    public func fetchSecureNotes(matching query: String = "") throws -> [SecureNote] {
        var predicate: Predicate<SecureNote>?
        if !query.isEmpty {
            predicate = #Predicate<SecureNote> { $0.title.localizedStandardContains(query) }
        }
        let descriptor = FetchDescriptor<SecureNote>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.title)]
        )
        return try context.fetch(descriptor)
    }

    // MARK: - Audit

    @discardableResult
    private func log(_ action: AuditAction, for credential: Credential) -> AuditRecord {
        let record = AuditRecord(credentialID: credential.id, action: action)
        context.insert(record)
        try? context.save()
        return record
    }

    // MARK: - Store URL

    private static var storeURL: URL {
        // App Group container is preferred when provisioned (Phase 4 CloudKit + AutoFill share access).
        // Falls back to applicationSupportDirectory for personal-team / simulator builds where
        // the App Group entitlement is not provisioned.
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.scottnguyen.passtrack"
        ) {
            let dir = groupURL.appending(component: "Library/Application Support", directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir.appending(component: "vault.store", directoryHint: .notDirectory)
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appending(component: "vault.store", directoryHint: .notDirectory)
    }
}
