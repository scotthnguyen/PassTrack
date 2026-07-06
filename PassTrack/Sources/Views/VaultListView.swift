import PassTrackKit
import SwiftUI

struct VaultListView: View {
    @Environment(AppModel.self) private var appModel
    @State private var searchText = ""
    @State private var credentials: [Credential] = []
    @State private var passkeys: [Passkey] = []
    @State private var secureNotes: [SecureNote] = []
    @State private var showAddCredential = false
    @State private var showAddNote = false
    @State private var showAddMenu = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if credentials.isEmpty && passkeys.isEmpty && secureNotes.isEmpty && searchText.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Vault")
            .searchable(text: $searchText, prompt: "Search credentials")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showAddCredential = true
                        } label: {
                            Label("New Login", systemImage: "key.fill")
                        }
                        Button {
                            showAddNote = true
                        } label: {
                            Label("New Secure Note", systemImage: "note.text")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add item")
                    .accessibilityHint("Choose to add a new login or secure note")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        appModel.lock()
                    } label: {
                        Image(systemName: "lock")
                    }
                    .accessibilityLabel("Lock vault")
                    .accessibilityHint("Locks PassTrack and clears the vault from memory")
                }
            }
            .sheet(isPresented: $showAddCredential) {
                AddEditCredentialView(mode: .add)
            }
            .sheet(isPresented: $showAddNote) {
                AddEditSecureNoteView(mode: .add)
            }
            .task(id: searchText) {
                await refresh()
            }
            .refreshable {
                await refresh()
            }
        }
        .accessibilityRotor("Logins") {
            ForEach(credentials) { c in
                AccessibilityRotorEntry(c.title, id: c.id)
            }
        }
        .accessibilityRotor("Passkeys") {
            ForEach(passkeys) { p in
                AccessibilityRotorEntry(p.userName, id: p.id)
            }
        }
        .accessibilityRotor("Secure Notes") {
            ForEach(secureNotes) { n in
                AccessibilityRotorEntry(n.title, id: n.id)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Credentials",
            systemImage: "key.slash",
            description: Text("Tap + to add your first login or secure note.")
        )
    }

    private var list: some View {
        List {
            if !credentials.isEmpty {
                Section("Logins") {
                    ForEach(credentials) { credential in
                        NavigationLink {
                            CredentialDetailView(credential: credential)
                        } label: {
                            CredentialRow(credential: credential)
                        }
                        .accessibilityLabel(credential.title)
                        .accessibilityHint("Double tap to view \(credential.username) for \(credential.title)")
                    }
                    .onDelete(perform: deleteCredentials)
                }
            }

            if !passkeys.isEmpty {
                Section("Passkeys") {
                    ForEach(passkeys) { passkey in
                        PasskeyRow(passkey: passkey)
                    }
                }
            }

            if !secureNotes.isEmpty {
                Section("Secure Notes") {
                    ForEach(secureNotes) { note in
                        NavigationLink {
                            SecureNoteDetailView(note: note)
                        } label: {
                            SecureNoteRow(note: note)
                        }
                        .accessibilityLabel(note.title)
                        .accessibilityHint("Double tap to view secure note")
                    }
                    .onDelete(perform: deleteNotes)
                }
            }
        }
    }

    private func refresh() async {
        do {
            credentials = try appModel.store.fetchCredentials(matching: searchText)
            passkeys = try appModel.store.fetchPasskeys()
            secureNotes = try appModel.store.fetchSecureNotes(matching: searchText)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteCredentials(at offsets: IndexSet) {
        for index in offsets {
            try? appModel.store.delete(credentials[index])
        }
        Task { await refresh() }
    }

    private func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            try? appModel.store.delete(secureNotes[index])
        }
        Task { await refresh() }
    }
}

private struct CredentialRow: View {
    let credential: Credential

    var body: some View {
        HStack {
            FaviconView(domain: credential.hostDomain)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(credential.title)
                    .font(.body)

                Text(credential.username)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if credential.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Favorite")
            }
        }
        .padding(.vertical, 2)
    }
}

private struct PasskeyRow: View {
    let passkey: Passkey

    var body: some View {
        HStack {
            Image(systemName: "person.badge.key.fill")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(passkey.relyingPartyName ?? passkey.relyingPartyID)
                    .font(.body)

                Text(passkey.userName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityLabel("Passkey for \(passkey.relyingPartyName ?? passkey.relyingPartyID), \(passkey.userName)")
    }
}

private struct SecureNoteRow: View {
    let note: SecureNote

    var body: some View {
        HStack {
            Image(systemName: "note.text")
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)
                .background(.tint.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(note.title)
                    .font(.body)

                Text(note.updatedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct FaviconView: View {
    let domain: String?

    var body: some View {
        Group {
            if let domain, !domain.isEmpty {
                AsyncImage(url: URL(string: "https://\(domain)/favicon.ico")) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    iconFallback
                }
            } else {
                iconFallback
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var iconFallback: some View {
        Image(systemName: "globe")
            .font(.title3)
            .foregroundStyle(.tint)
            .frame(width: 36, height: 36)
            .background(.tint.opacity(0.1))
    }
}
