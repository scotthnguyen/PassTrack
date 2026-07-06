import PassTrackKit
import SwiftUI

enum SecureNoteFormMode {
    case add
    case edit(SecureNote)
}

struct AddEditSecureNoteView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    let mode: SecureNoteFormMode

    @State private var title = ""
    @State private var content = ""
    @State private var errorMessage: String?

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Note title", text: $title)
                        .accessibilityLabel("Note title")
                        .accessibilityHint("A name for this secure note")
                }

                Section("Content") {
                    TextEditor(text: $content)
                        .frame(minHeight: 160)
                        .accessibilityLabel("Note content")
                        .accessibilityHint("The private content of this secure note")
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Error: \(errorMessage)")
                }
            }
            .navigationTitle(isEditing ? "Edit Note" : "New Secure Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add", action: save)
                        .disabled(title.isEmpty || content.isEmpty)
                }
            }
        }
        .onAppear(perform: populateIfEditing)
    }

    private func populateIfEditing() {
        guard case .edit(let note) = mode else { return }
        title = note.title
        content = (try? appModel.store.decrypt(note.encryptedContent)) ?? ""
    }

    private func save() {
        do {
            switch mode {
            case .add:
                try appModel.store.addSecureNote(title: title, content: content)
            case .edit(let note):
                try appModel.store.updateSecureNote(note, title: title, content: content)
            }
            dismiss()
        } catch {
            errorMessage = "Failed to save note. Please try again."
            UIAccessibility.post(notification: .announcement, argument: errorMessage!)
        }
    }
}
