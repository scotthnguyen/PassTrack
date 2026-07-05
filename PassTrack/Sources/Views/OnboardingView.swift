import PassTrackKit
import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var appModel
    @State private var passphrase = ""
    @State private var confirmPassphrase = ""
    @State private var errorMessage: String?
    @State private var step: Step = .welcome

    enum Step { case welcome, passphrase }

    var body: some View {
        NavigationStack {
            switch step {
            case .welcome:
                welcomeStep
            case .passphrase:
                passphraseStep
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
                withAnimation { step = .passphrase }
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
                Text("If you forget this passphrase, your vault cannot be recovered. Write it down and store it safely.")
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
                Button("Create Vault", action: createVault)
                    .disabled(passphrase.isEmpty || confirmPassphrase.isEmpty)
            }
        }
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
        } catch {
            errorMessage = "Failed to create vault. Please try again."
            UIAccessibility.post(notification: .announcement, argument: errorMessage!)
        }
    }
}
