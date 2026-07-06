import PassTrackKit
import SwiftUI

enum CredentialFormMode {
    case add
    case edit(Credential)
}

struct AddEditCredentialView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    let mode: CredentialFormMode

    @State private var title = ""
    @State private var username = ""
    @State private var password = ""
    @State private var websiteURL = ""
    @State private var notes = ""
    @State private var totpSecret = ""
    @State private var isFavorite = false
    @State private var showGenerator = false
    @State private var errorMessage: String?

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Title", text: $title)
                        .accessibilityLabel("Title")
                        .accessibilityHint("Name for this credential, for example Netflix or Work Email")

                    TextField("Username or email", text: $username)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Username or email")

                    HStack {
                        SecureField("Password", text: $password)
                            .accessibilityLabel("Password")

                        Button {
                            showGenerator = true
                        } label: {
                            Image(systemName: "key.fill")
                        }
                        .accessibilityLabel("Generate password")
                        .accessibilityHint("Opens the password generator to create a strong password")
                    }
                }

                Section("Website") {
                    TextField("https://example.com", text: $websiteURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Website URL")
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                        .accessibilityLabel("Notes")
                }

                Section("Two-Factor Authentication") {
                    TextField("TOTP secret key (optional)", text: $totpSecret)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                        .accessibilityLabel("TOTP secret key")
                        .accessibilityHint("Optional. Paste the base32 secret from an authenticator setup page to generate two-factor codes.")
                }

                Section {
                    Toggle("Favorite", isOn: $isFavorite)
                        .accessibilityHint("Marks this credential as a favorite for quick access")
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Error: \(errorMessage)")
                }
            }
            .navigationTitle(isEditing ? "Edit Credential" : "New Credential")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add", action: save)
                        .disabled(title.isEmpty || username.isEmpty || password.isEmpty)
                }
            }
            .sheet(isPresented: $showGenerator) {
                PasswordGeneratorView(selectedPassword: $password)
            }
        }
        .onAppear(perform: populateIfEditing)
    }

    private func populateIfEditing() {
        guard case .edit(let credential) = mode else { return }
        title = credential.title
        username = credential.username
        websiteURL = credential.websiteURL ?? ""
        notes = credential.notes ?? ""
        totpSecret = credential.totpSecret ?? ""
        isFavorite = credential.isFavorite
        if let decrypted = try? appModel.store.decrypt(credential.encryptedPassword) {
            password = decrypted
        }
    }

    private func save() {
        do {
            switch mode {
            case .add:
                try appModel.store.addCredential(
                    title: title,
                    username: username,
                    password: password,
                    websiteURL: websiteURL.isEmpty ? nil : websiteURL,
                    notes: notes.isEmpty ? nil : notes,
                    totpSecret: totpSecret.isEmpty ? nil : totpSecret
                )
            case .edit(let credential):
                credential.title = title
                credential.username = username
                credential.websiteURL = websiteURL.isEmpty ? nil : websiteURL
                credential.notes = notes.isEmpty ? nil : notes
                credential.totpSecret = totpSecret.isEmpty ? nil : totpSecret
                credential.isFavorite = isFavorite
                try appModel.store.updateCredential(credential, password: password.isEmpty ? nil : password)
            }
            dismiss()
        } catch {
            errorMessage = "Failed to save credential. Please try again."
            UIAccessibility.post(notification: .announcement, argument: errorMessage!)
        }
    }
}
