import Foundation
import SwiftData

public enum AuditAction: String, Codable, Sendable {
    case credentialViewed
    case credentialCopied
    case credentialFilled
    case credentialCreated
    case credentialUpdated
    case credentialDeleted
    case passkeyCreated
    case passkeyAsserted
    case vaultUnlocked
    case vaultLocked
}

@Model
public final class AuditRecord {
    public var id: UUID
    public var credentialID: UUID?
    public var action: String
    public var timestamp: Date
    public var metadata: String?

    public init(
        id: UUID = UUID(),
        credentialID: UUID? = nil,
        action: AuditAction,
        metadata: String? = nil
    ) {
        self.id = id
        self.credentialID = credentialID
        self.action = action.rawValue
        self.timestamp = .now
        self.metadata = metadata
    }

    public var auditAction: AuditAction? {
        AuditAction(rawValue: action)
    }
}
