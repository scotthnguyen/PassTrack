import PassTrackKit
import SwiftUI

struct PasswordGeneratorView: View {
    @Binding var selectedPassword: String
    @Environment(\.dismiss) private var dismiss

    @State private var options = PasswordOptions()
    @State private var generated = ""
    @State private var strength: PasswordStrength = .strong

    init(selectedPassword: Binding<String> = .constant("")) {
        _selectedPassword = selectedPassword
        let initial = PasswordGenerator.generate()
        _generated = State(initialValue: initial)
        _strength = State(initialValue: PasswordGenerator.strength(of: initial))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(generated)
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                                .accessibilityLabel("Generated password: \(generated)")

                            Spacer()

                            Button {
                                regenerate()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .accessibilityLabel("Regenerate password")
                            .accessibilityHint("Generates a new password with the same settings")
                        }

                        HStack(spacing: 8) {
                            Image(systemName: strength.symbolName)
                                .accessibilityHidden(true)

                            Text(strength.rawValue)
                                .font(.caption.bold())

                            Spacer()
                        }
                        .foregroundStyle(strengthColor)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(strength.accessibilityDescription)
                    }
                    .padding(.vertical, 4)
                }

                Section("Style") {
                    Picker("Style", selection: $options.style) {
                        ForEach(PasswordStyle.allCases, id: \.self) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: options.style) { _, _ in regenerate() }
                    .accessibilityLabel("Password style")
                }

                if options.style != .passphrase {
                    Section("Length: \(options.length)") {
                        Slider(value: Binding(
                            get: { Double(options.length) },
                            set: { options.length = Int($0); regenerate() }
                        ), in: 8...64, step: 1)
                        .accessibilityLabel("Password length: \(options.length) characters")
                    }

                    Section("Characters") {
                        Toggle("Uppercase (A–Z)", isOn: toggle(\.includeUppercase))
                        Toggle("Lowercase (a–z)", isOn: toggle(\.includeLowercase))
                        Toggle("Numbers (0–9)", isOn: toggle(\.includeNumbers))
                        Toggle("Symbols (!@#…)", isOn: toggle(\.includeSymbols))
                    }
                } else {
                    Section("Word count: \(options.wordCount)") {
                        Slider(value: Binding(
                            get: { Double(options.wordCount) },
                            set: { options.wordCount = Int($0); regenerate() }
                        ), in: 3...8, step: 1)
                        .accessibilityLabel("Passphrase word count: \(options.wordCount) words")
                    }
                }

                Section {
                    Button("Use This Password") {
                        selectedPassword = generated
                        dismiss()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityHint("Inserts this password into the password field")
                }
            }
            .navigationTitle("Password Generator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var strengthColor: Color {
        switch strength {
        case .weak: return .red
        case .fair: return .orange
        case .strong: return .green
        case .veryStrong: return .blue
        }
    }

    private func toggle(_ path: WritableKeyPath<PasswordOptions, Bool>) -> Binding<Bool> {
        Binding(
            get: { options[keyPath: path] },
            set: { options[keyPath: path] = $0; regenerate() }
        )
    }

    private func regenerate() {
        generated = PasswordGenerator.generate(options: options)
        strength = PasswordGenerator.strength(of: generated)
    }
}
