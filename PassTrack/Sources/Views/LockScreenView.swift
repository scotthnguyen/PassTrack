import PassTrackKit
import SwiftUI

struct LockScreenView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var passphrase = ""
    @State private var recoveryCode = ""
    @State private var mode: UnlockMode = .biometric
    @State private var errorMessage: String?
    @FocusState private var fieldFocused: Bool

    enum UnlockMode { case biometric, passphrase, recoveryCode }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.tint)
                    .accessibilityLabel("PassTrack locked")

                VStack(spacing: 4) {
                    Text("PassTrack")
                        .font(.largeTitle.bold())
                    Text("Your vault is locked")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 16) {
                    switch mode {
                    case .biometric:
                        biometricControls
                    case .passphrase:
                        passphraseControls
                    case .recoveryCode:
                        recoveryCodeControls
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .accessibilityLabel("Error: \(errorMessage)")
                    }
                }
                .padding(24)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .task {
            await appModel.unlockWithBiometrics()
        }
        .sheet(isPresented: Binding(
            get: { appModel.needsPassphraseReset },
            set: { _ in }
        )) {
            SetNewPassphraseView()
        }
    }

    private var biometricControls: some View {
        VStack(spacing: 12) {
            Button {
                Task { await appModel.unlockWithBiometrics() }
            } label: {
                Label("Unlock with Face ID", systemImage: "faceid")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            modeToggleButton(label: "Use passphrase", target: .passphrase)
            modeToggleButton(label: "Use recovery code", target: .recoveryCode)
        }
    }

    private var passphraseControls: some View {
        VStack(spacing: 12) {
            SecureField("Master passphrase", text: $passphrase)
                .textFieldStyle(.roundedBorder)
                .focused($fieldFocused)
                .onSubmit(unlockWithPassphrase)
                .accessibilityLabel("Master passphrase")
                .accessibilityHint("Enter your passphrase and press Return to unlock")
                .onAppear { fieldFocused = true }

            Button("Unlock", action: unlockWithPassphrase)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(passphrase.isEmpty)

            modeToggleButton(label: "Cancel", target: .biometric)
        }
    }

    private var recoveryCodeControls: some View {
        VStack(spacing: 12) {
            TextField("XXXXX-XXXXX-XXXXX-XXXXX-XXXXX", text: $recoveryCode)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.body.monospaced())
                .focused($fieldFocused)
                .onSubmit(unlockWithRecoveryCode)
                .accessibilityLabel("Recovery code")
                .accessibilityHint("Enter the 25-character recovery code you received when setting up PassTrack")
                .onAppear { fieldFocused = true }

            Button("Unlock with Recovery Code", action: unlockWithRecoveryCode)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(recoveryCode.isEmpty)

            modeToggleButton(label: "Cancel", target: .biometric)
        }
    }

    private func modeToggleButton(label: String, target: UnlockMode) -> some View {
        Button(label) {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) {
                mode = target
                passphrase = ""
                recoveryCode = ""
                errorMessage = nil
                fieldFocused = target != .biometric
            }
        }
        .foregroundStyle(.secondary)
    }

    private func unlockWithPassphrase() {
        do {
            try appModel.unlock(passphrase: passphrase)
            passphrase = ""
            errorMessage = nil
        } catch {
            errorMessage = "Incorrect passphrase. Please try again."
            passphrase = ""
            UIAccessibility.post(notification: .announcement, argument: errorMessage!)
        }
    }

    private func unlockWithRecoveryCode() {
        do {
            try appModel.unlock(recoveryCode: recoveryCode)
            recoveryCode = ""
            errorMessage = nil
        } catch {
            errorMessage = "Invalid recovery code. Check for typos and try again."
            UIAccessibility.post(notification: .announcement, argument: errorMessage!)
        }
    }
}

/// Shown immediately after a recovery-code unlock so the user sets a known passphrase.
private struct SetNewPassphraseView: View {
    @Environment(AppModel.self) private var appModel
    @State private var newPassphrase = ""
    @State private var confirmPassphrase = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("New passphrase", text: $newPassphrase)
                        .accessibilityLabel("New passphrase")
                    SecureField("Confirm new passphrase", text: $confirmPassphrase)
                        .accessibilityLabel("Confirm new passphrase")
                } header: {
                    Text("Set a new passphrase")
                } footer: {
                    Text("Your recovery code worked. Set a new passphrase so you can unlock PassTrack next time.")
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Error: \(errorMessage)")
                }
            }
            .navigationTitle("New Passphrase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(newPassphrase.isEmpty || confirmPassphrase.isEmpty)
                }
            }
        }
        .interactiveDismissDisabled()
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
            appModel.needsPassphraseReset = false
        } catch {
            errorMessage = "Failed to update passphrase. Please try again."
            UIAccessibility.post(notification: .announcement, argument: errorMessage!)
        }
    }
}
