import Foundation
import SwiftData

@Model
public final class Tag {
    public var id: UUID
    public var name: String
    public var colorHex: String

    public var credentials: [Credential]
    public var secureNotes: [SecureNote]

    public init(id: UUID = UUID(), name: String, colorHex: String = "#007AFF") {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.credentials = []
        self.secureNotes = []
    }
}
