import PassTrackKit
import SwiftUI

struct LockScreenView: View {
    @Environment(AppModel.self) private var appModel
    @State private var passphrase = ""
    @State private var showPassphraseEntry = false
    @State private var errorMessage: String?
    @FocusState private var passphraseFieldFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
                .accessibilityLabel("PassTrack locked")

            Text("PassTrack")
                .font(.largeTitle.bold())

            Text("Your vault is locked")
                .foregroundStyle(.secondary)

            Spacer()

            VStack(spacing: 16) {
                if showPassphraseEntry {
                    SecureField("Master passphrase", text: $passphrase)
                        .textFieldStyle(.roundedBorder)
                        .focused($passphraseFieldFocused)
                        .onSubmit(unlockWithPassphrase)
                        .accessibilityLabel("Master passphrase")
                        .accessibilityHint("Enter your passphrase and press Return to unlock")

                    Button("Unlock", action: unlockWithPassphrase)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .disabled(passphrase.isEmpty)
                }

                Button {
                    Task { await appModel.unlockWithBiometrics() }
                } label: {
                    Label("Unlock with Face ID", systemImage: "faceid")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(showPassphraseEntry ? "Cancel" : "Use passphrase") {
                    withAnimation {
                        showPassphraseEntry.toggle()
                        passphraseFieldFocused = showPassphraseEntry
                        if !showPassphraseEntry { passphrase = "" }
                    }
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Error: \(errorMessage)")
            }

            Spacer()
        }
        .task {
            await appModel.unlockWithBiometrics()
        }
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
}
