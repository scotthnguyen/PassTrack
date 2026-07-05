import AppIntents
import PassTrackKit
import Foundation

public struct CredentialEntity: AppEntity, Sendable {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Credential")
    public static let defaultQuery = CredentialQuery()

    public var id: UUID
    public var title: String
    public var username: String
    public var websiteURL: String?

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(username)"
        )
    }

    init(credential: Credential) {
        self.id = credential.id
        self.title = credential.title
        self.username = credential.username
        self.websiteURL = credential.websiteURL
    }
}

public struct CredentialQuery: EntityQuery, Sendable {
    @MainActor
    public func entities(for identifiers: [UUID]) async throws -> [CredentialEntity] {
        let store = VaultStore.shared
        guard !store.isLocked else { return [] }
        let all = try store.fetchCredentials()
        return all
            .filter { identifiers.contains($0.id) }
            .map { CredentialEntity(credential: $0) }
    }

    @MainActor
    public func suggestedEntities() async throws -> [CredentialEntity] {
        let store = VaultStore.shared
        guard !store.isLocked else { return [] }
        let all = try store.fetchCredentials()
        return all.prefix(10).map { CredentialEntity(credential: $0) }
    }
}
