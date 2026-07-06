import PassTrackKit
import SwiftUI

struct CredentialDetailView: View {
    @Environment(AppModel.self) private var appModel
    let credential: Credential

    @State private var decryptedPassword: String?
    @State private var isPasswordVisible = false
    @State private var showEditSheet = false
    @State private var clipboardCountdown: Int?
    @State private var countdownTask: Task<Void, Never>?

    private let clipboardTimeout = 30

    var body: some View {
        List {
            Section("Account") {
                LabeledContent("Title", value: credential.title)
                LabeledContent("Username", value: credential.username)
                    .contextMenu {
                        Button("Copy Username") {
                            copy(credential.username, label: "Username")
                        }
                    }

                HStack {
                    LabeledContent("Password") {
                        Group {
                            if let pwd = decryptedPassword {
                                if isPasswordVisible {
                                    Text(pwd)
                                        .font(.body.monospaced())
                                        .textSelection(.enabled)
                                } else {
                                    Text(String(repeating: "•", count: min(pwd.count, 12)))
                                        .font(.body.monospaced())
                                }
                            } else {
                                ProgressView()
                            }
                        }
                    }

                    Button {
                        isPasswordVisible.toggle()
                        UIAccessibility.post(
                            notification: .announcement,
                            argument: isPasswordVisible ? "Password shown" : "Password hidden"
                        )
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                    }
                    .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
                }

                if let pwd = decryptedPassword {
                    Button {
                        copy(pwd, label: "Password")
                    } label: {
                        HStack {
                            Label(
                                clipboardCountdown != nil
                                    ? "Copied — clears in \(clipboardCountdown!)s"
                                    : "Copy Password",
                                systemImage: clipboardCountdown != nil ? "checkmark" : "doc.on.doc"
                            )
                        }
                    }
                    .accessibilityHint("Copies password to clipboard and clears it after \(clipboardTimeout) seconds")
                }
            }

            if let url = credential.websiteURL, !url.isEmpty {
                Section("Website") {
                    LabeledContent("URL", value: url)
                    if let parsed = URL(string: url) {
                        Link("Open in Safari", destination: parsed)
                    }
                }
            }

            if let notes = credential.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .font(.body)
                        .accessibilityLabel("Notes: \(notes)")
                }
            }

            if let totp = credential.totpSecret, !totp.isEmpty {
                Section("Two-Factor Code") {
                    TOTPView(secret: totp)
                }
            }

            Section("Details") {
                LabeledContent("Added", value: credential.createdAt.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Updated", value: credential.updatedAt.formatted(date: .abbreviated, time: .omitted))
            }
        }
        .navigationTitle(credential.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEditSheet = true }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AddEditCredentialView(mode: .edit(credential))
        }
        .task {
            await decryptPassword()
        }
    }

    private func decryptPassword() async {
        do {
            decryptedPassword = try appModel.store.decrypt(credential.encryptedPassword)
        } catch {
            decryptedPassword = "[decryption failed]"
        }
    }

    private func copy(_ value: String, label: String) {
        UIPasteboard.general.string = value
        UIAccessibility.post(
            notification: .announcement,
            argument: "\(label) copied. Will clear from clipboard in \(clipboardTimeout) seconds."
        )
        countdownTask?.cancel()
        clipboardCountdown = clipboardTimeout
        countdownTask = Task {
            for i in stride(from: clipboardTimeout, through: 1, by: -1) {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                await MainActor.run { clipboardCountdown = i - 1 }
            }
            await MainActor.run {
                if UIPasteboard.general.string == value {
                    UIPasteboard.general.string = ""
                }
                clipboardCountdown = nil
            }
        }
    }
}

private struct TOTPView: View {
    let secret: String
    @State private var code: String = "------"
    @State private var secondsRemaining: Int = 30
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 16) {
            TOTPRingView(secondsRemaining: secondsRemaining, reduceMotion: reduceMotion)

            VStack(alignment: .leading, spacing: 2) {
                Text(formattedCode)
                    .font(.title2.monospaced().bold())
                    .accessibilityLabel("Two-factor code: \(code.map { String($0) }.joined(separator: " "))")

                Text("\(secondsRemaining)s remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            Spacer()

            Button {
                UIPasteboard.general.string = code
                UIAccessibility.post(notification: .announcement, argument: "Code copied")
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .accessibilityLabel("Copy two-factor code")
            .accessibilityHint("Copies the current \(secondsRemaining) second code to clipboard")
        }
        .task {
            await refreshCode()
        }
    }

    private var formattedCode: String {
        guard code.count == 6 else { return code }
        return "\(code.prefix(3)) \(code.suffix(3))"
    }

    private func refreshCode() async {
        while !Task.isCancelled {
            let now = Int(Date().timeIntervalSince1970)
            let remaining = 30 - (now % 30)
            secondsRemaining = remaining
            code = TOTPGenerator.generate(secret: secret, time: Date())
            try? await Task.sleep(for: .seconds(1))
        }
    }
}

private struct TOTPRingView: View {
    let secondsRemaining: Int
    let reduceMotion: Bool

    private var fraction: CGFloat { CGFloat(secondsRemaining) / 30 }

    private var ringColor: Color {
        if secondsRemaining > 20 { return .green }
        if secondsRemaining > 10 { return .orange }
        return .red
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 1), value: secondsRemaining)
            Text("\(secondsRemaining)")
                .font(.caption2.bold())
                .foregroundStyle(ringColor)
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }
}
