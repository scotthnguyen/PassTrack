import PassTrackKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var autoLockIndex = 1
    @State private var clipboardTimeoutIndex = 1

    private let autoLockOptions: [(String, TimeInterval)] = [
        ("Immediately", 0),
        ("1 minute", 60),
        ("5 minutes", 300),
        ("15 minutes", 900),
        ("1 hour", 3600),
        ("Never", .infinity)
    ]

    private let clipboardOptions: [(String, TimeInterval)] = [
        ("15 seconds", 15),
        ("30 seconds", 30),
        ("1 minute", 60),
        ("Never", .infinity)
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Security") {
                    Picker("Auto-lock", selection: $autoLockIndex) {
                        ForEach(autoLockOptions.indices, id: \.self) { i in
                            Text(autoLockOptions[i].0).tag(i)
                        }
                    }
                    .accessibilityLabel("Auto-lock timeout")
                    .accessibilityHint("How long before PassTrack automatically locks when inactive")
                    .onChange(of: autoLockIndex) { _, i in
                        appModel.autoLockInterval = autoLockOptions[i].1
                    }

                    Picker("Clipboard timeout", selection: $clipboardTimeoutIndex) {
                        ForEach(clipboardOptions.indices, id: \.self) { i in
                            Text(clipboardOptions[i].0).tag(i)
                        }
                    }
                    .accessibilityLabel("Clipboard timeout")
                    .accessibilityHint("How long before copied passwords are cleared from the clipboard")
                    .onChange(of: clipboardTimeoutIndex) { _, i in
                        appModel.clipboardTimeout = clipboardOptions[i].1
                    }

                    Button("Lock Now") {
                        appModel.lock()
                    }
                    .foregroundStyle(.red)
                    .accessibilityHint("Immediately locks PassTrack and clears the vault from memory")
                }

                Section("Sync") {
                    LabeledContent("iCloud Sync", value: "On")
                        .accessibilityLabel("iCloud sync is enabled. Your vault is encrypted before leaving this device.")
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    Link("Privacy Policy", destination: URL(string: "https://scottnguyen.com/passtrack/privacy")!)
                    Link("Accessibility Statement", destination: URL(string: "https://scottnguyen.com/passtrack/accessibility")!)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
