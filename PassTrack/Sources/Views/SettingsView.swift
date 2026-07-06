import PassTrackKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var autoLockIndex = 1
    @State private var clipboardTimeoutIndex = 1
    @State private var showChangePassphrase = false

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

                    Button("Change Passphrase") {
                        showChangePassphrase = true
                    }
                    .accessibilityHint("Set a new master passphrase. Your saved passwords are not affected.")

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
            .sheet(isPresented: $showChangePassphrase) {
                ChangePassphraseView()
            }
        }
    }
}

private struct ChangePassphraseView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    @State private var newPassphrase = ""
    @State private var confirmPassphrase = ""
    @State private var errorMessage: String?
    @State private var didSucceed = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("New passphrase", text: $newPassphrase)
                        .accessibilityLabel("New passphrase")
                    SecureField("Confirm new passphrase", text: $confirmPassphrase)
                        .accessibilityLabel("Confirm new passphrase")
                } header: {
                    Text("New passphrase")
                } footer: {
                    Text("Your saved passwords are not affected — only the passphrase used to unlock PassTrack changes.")
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Error: \(errorMessage)")
                }

                if didSucceed {
                    Label("Passphrase updated.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("Passphrase updated successfully.")
                }
            }
            .navigationTitle("Change Passphrase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(newPassphrase.isEmpty || confirmPassphrase.isEmpty)
                }
            }
        }
    }

    private func save() {
        guard newPassphrase == confirmPassphrase else {
            errorMessage = "Passphrases do not match."
            UIAccessibility.post(notification: .announcement, argument: errorMessage!)
            return
        }
        guard newPassphrase.count >= 8 else {
            errorMessage = "Passphrase must be at least 8 characters."
            UIAccessibility.post(notification: .announcement, argument: errorMessage!)
            return
        }
        do {
            try appModel.store.changePassphrase(to: newPassphrase)
            didSucceed = true
            errorMessage = nil
            UIAccessibility.post(notification: .announcement, argument: "Passphrase updated successfully.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
        } catch {
            errorMessage = "Failed to update passphrase. Please try again."
            UIAccessibility.post(notification: .announcement, argument: errorMessage!)
        }
    }
}
