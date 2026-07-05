import Foundation
import SwiftData

@Model
public final class Credential {
    public var id: UUID
    public var title: String
    public var username: String
    public var encryptedPassword: Data
    public var websiteURL: String?
    public var notes: String?
    public var isFavorite: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var lastUsedAt: Date?
    public var totpSecret: String?

    @Relationship(deleteRule: .nullify, inverse: \Tag.credentials)
    public var tags: [Tag]

    public init(
        id: UUID = UUID(),
        title: String,
        username: String,
        encryptedPassword: Data,
        websiteURL: String? = nil,
        notes: String? = nil,
        isFavorite: Bool = false,
        totpSecret: String? = nil
    ) {
        self.id = id
        self.title = title
        self.username = username
        self.encryptedPassword = encryptedPassword
        self.websiteURL = websiteURL
        self.notes = notes
        self.isFavorite = isFavorite
        self.totpSecret = totpSecret
        self.createdAt = .now
        self.updatedAt = .now
        self.tags = []
    }

    public var hostDomain: String? {
        guard let urlString = websiteURL,
              let host = URL(string: urlString)?.host else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
