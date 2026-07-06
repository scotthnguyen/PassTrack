import PassTrackKit
import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var passphrase = ""
    @State private var confirmPassphrase = ""
    @State private var errorMessage: String?
    @State private var step: Step = .welcome

    enum Step { case welcome, passphrase, recoveryCode }

    var body: some View {
        NavigationStack {
            switch step {
            case .welcome:
                welcomeStep
            case .passphrase:
                passphraseStep
            case .recoveryCode:
                recoveryCodeStep
            }
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("Welcome to PassTrack")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("A private, accessible credential manager built for everyone.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button("Get Started") {
                withAnimation(reduceMotion ? nil : .default) { step = .passphrase }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)

            Spacer()
        }
        .navigationBarHidden(true)
    }

    private var passphraseStep: some View {
        Form {
            Section {
                SecureField("Master passphrase", text: $passphrase)
                    .accessibilityLabel("Master passphrase")
                    .accessibilityHint("This passphrase is used as a fallback if Face ID is unavailable. It cannot be recovered.")

                SecureField("Confirm passphrase", text: $confirmPassphrase)
                    .accessibilityLabel("Confirm master passphrase")
            } header: {
                Text("Create a master passphrase")
            } footer: {
                Text("If you forget this passphrase, you can recover access using the recovery code shown on the next screen.")
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Error: \(errorMessage)")
            }
        }
        .navigationTitle("Secure Your Vault")
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Next", action: createVault)
                    .disabled(passphrase.isEmpty || confirmPassphrase.isEmpty)
            }
        }
    }

    private var recoveryCodeStep: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Write this down", systemImage: "pencil.and.list.clipboard")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(appModel.pendingRecoveryCode ?? "")
                            .font(.system(.title2, design: .monospaced, weight: .bold))
                            .tracking(2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .textSelection(.enabled)
                            .accessibilityLabel("Recovery code: \(appModel.pendingRecoveryCode ?? "")")
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Your recovery code")
                } footer: {
                    Text("This code is the only way to recover your vault if you forget your passphrase and Face ID is unavailable. Store it somewhere safe — a notebook, printed page, or a different password manager. PassTrack will never show it again.")
                }
            }

            Button("I've written it down safely") {
                appModel.acknowledgeRecoveryCode()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .accessibilityHint("Confirms you have saved your recovery code and opens the vault")
        }
        .navigationTitle("Recovery Code")
        .navigationBarBackButtonHidden()
    }

    private func createVault() {
        guard passphrase == confirmPassphrase else {
            errorMessage = "Passphrases do not match."
            UIAccessibility.post(notification: .announcement, argument: errorMessage!)
            return
        }
        guard passphrase.count >= 8 else {
            errorMessage = "Passphrase must be at least 8 characters."
            UIAccessibility.post(notification: .announcement, argument: errorMessage!)
            return
        }
        do {
            try appModel.setupVault(passphrase: passphrase)
            withAnimation(reduceMotion ? nil : .default) { step = .recoveryCode }
        } catch {
            errorMessage = "Failed to create vault. Please try again."
            UIAccessibility.post(notification: .announcement, argument: errorMessage!)
        }
    }
}
