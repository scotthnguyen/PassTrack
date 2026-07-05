import Foundation
import SwiftData

@Model
public final class Passkey {
    public var id: UUID
    public var relyingPartyID: String
    public var relyingPartyName: String?
    public var userName: String
    public var userHandle: Data
    public var credentialID: Data
    public var createdAt: Date
    public var lastUsedAt: Date?

    public init(
        id: UUID = UUID(),
        relyingPartyID: String,
        relyingPartyName: String? = nil,
        userName: String,
        userHandle: Data,
        credentialID: Data
    ) {
        self.id = id
        self.relyingPartyID = relyingPartyID
        self.relyingPartyName = relyingPartyName
        self.userName = userName
        self.userHandle = userHandle
        self.credentialID = credentialID
        self.createdAt = .now
    }
}
