import AppIntents
import PassTrackKit
import Foundation

struct RetrieveCredentialIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Credential"
    static let description = IntentDescription(
        "Retrieves a saved login and opens it in PassTrack.",
        categoryName: "Credentials"
    )
    static let openAppWhenRun = true

    @Parameter(title: "Credential")
    var credential: CredentialEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        NotificationCenter.default.post(
            name: .deepLinkReceived,
            object: URL(string: "passtrack://credential/\(credential.id.uuidString)")
        )
        return .result(
            dialog: "Opening \(credential.title) for \(credential.username)."
        )
    }
}
