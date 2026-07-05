import Foundation
import SwiftData

@Model
public final class SecureNote {
    public var id: UUID
    public var title: String
    public var encryptedContent: Data
    public var createdAt: Date
    public var updatedAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Tag.secureNotes)
    public var tags: [Tag]

    public init(id: UUID = UUID(), title: String, encryptedContent: Data) {
        self.id = id
        self.title = title
        self.encryptedContent = encryptedContent
        self.createdAt = .now
        self.updatedAt = .now
        self.tags = []
    }
}
