import AppIntents
import PassTrackKit
import Foundation

struct GeneratePasswordIntent: AppIntent {
    static let title: LocalizedStringResource = "Generate Password"
    static let description = IntentDescription(
        "Generates a strong random password.",
        categoryName: "Credentials"
    )

    @Parameter(title: "Length", default: 20)
    var length: Int

    @Parameter(title: "Include Symbols", default: false)
    var includeSymbols: Bool

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        var options = PasswordOptions()
        options.length = max(8, min(64, length))
        options.includeSymbols = includeSymbols
        let password = PasswordGenerator.generate(options: options)
        return .result(
            value: password,
            dialog: "Generated a \(options.length)-character password."
        )
    }
}
