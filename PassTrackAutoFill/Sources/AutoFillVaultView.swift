import PassTrackKit
import SwiftUI

struct AutoFillVaultView: View {
    @State var viewModel: AutoFillViewModel
    let onSelect: (Credential) -> Void
    let onCancel: () -> Void

    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLocked {
                    lockScreen
                } else if viewModel.isLoading {
                    ProgressView("Loading credentials…")
                        .accessibilityLabel("Loading your credentials")
                } else {
                    credentialList
                }
            }
            .navigationTitle("PassTrack")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .task {
            if !viewModel.isLocked {
                await viewModel.loadCredentials()
            } else {
                await viewModel.unlockWithBiometrics()
            }
        }
    }

    private var lockScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("Vault Locked")
                .font(.title2.bold())

            Button {
                Task { await viewModel.unlockWithBiometrics() }
            } label: {
                Label("Unlock with Face ID", systemImage: "faceid")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var credentialList: some View {
        List(filteredCredentials) { credential in
            Button {
                onSelect(credential)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(credential.title)
                        .font(.body)
                    Text(credential.username)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel("\(credential.title), \(credential.username)")
            .accessibilityHint("Double tap to fill this credential")
        }
        .searchable(text: $searchText, prompt: "Search")
        .overlay {
            if filteredCredentials.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private var filteredCredentials: [Credential] {
        guard !searchText.isEmpty else { return viewModel.credentials }
        return viewModel.credentials.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.username.localizedCaseInsensitiveContains(searchText)
        }
    }
}
