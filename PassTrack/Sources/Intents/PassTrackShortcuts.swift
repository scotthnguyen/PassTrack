import AppIntents

struct PassTrackShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RetrieveCredentialIntent(),
            phrases: [
                "Get my \(\.$credential) login in \(.applicationName)",
                "Open \(\.$credential) in \(.applicationName)"
            ],
            shortTitle: "Get Login",
            systemImageName: "key.fill"
        )
        AppShortcut(
            intent: GeneratePasswordIntent(),
            phrases: [
                "Generate a password in \(.applicationName)",
                "Make a strong password with \(.applicationName)"
            ],
            shortTitle: "Generate Password",
            systemImageName: "key.badge.plus"
        )
    }
}
