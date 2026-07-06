import PassTrackKit
import SwiftUI

struct SecureNoteDetailView: View {
    @Environment(AppModel.self) private var appModel
    let note: SecureNote

    @State private var decryptedContent: String?
    @State private var showEditSheet = false

    var body: some View {
        List {
            Section("Content") {
                if let content = decryptedContent {
                    Text(content)
                        .font(.body)
                        .textSelection(.enabled)
                        .accessibilityLabel("Note content: \(content)")
                } else {
                    ProgressView()
                        .accessibilityLabel("Decrypting note")
                }
            }

            Section("Details") {
                LabeledContent("Created", value: note.createdAt.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Updated", value: note.updatedAt.formatted(date: .abbreviated, time: .omitted))
            }
        }
        .navigationTitle(note.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEditSheet = true }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AddEditSecureNoteView(mode: .edit(note))
        }
        .task {
            decryptedContent = try? appModel.store.decrypt(note.encryptedContent)
        }
    }
}
