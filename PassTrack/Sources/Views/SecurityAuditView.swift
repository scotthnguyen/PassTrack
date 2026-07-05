import PassTrackKit
import SwiftUI

struct SecurityAuditView: View {
    @Environment(AppModel.self) private var appModel
    @State private var auditResults: AuditResults?

    var body: some View {
        NavigationStack {
            Group {
                if let results = auditResults {
                    auditList(results)
                } else {
                    ProgressView("Scanning vault…")
                        .accessibilityLabel("Scanning your vault for security issues")
                }
            }
            .navigationTitle("Security Audit")
        }
        .task {
            await runAudit()
        }
        // Custom rotor to jump between security issue types
        .accessibilityRotor("Weak Passwords") {
            if let results = auditResults {
                ForEach(results.weak) { c in
                    AccessibilityRotorEntry(c.title, id: c.id)
                }
            }
        }
        .accessibilityRotor("Reused Passwords") {
            if let results = auditResults {
                ForEach(results.reused) { c in
                    AccessibilityRotorEntry(c.title, id: c.id)
                }
            }
        }
    }

    private func auditList(_ results: AuditResults) -> some View {
        List {
            AuditSummarySection(results: results)

            if !results.weak.isEmpty {
                auditSection(
                    "Weak Passwords",
                    credentials: results.weak,
                    icon: "xmark.shield",
                    description: "These passwords are easy to guess. Change them to something longer with mixed characters.",
                    tint: .red
                )
            }

            if !results.reused.isEmpty {
                auditSection(
                    "Reused Passwords",
                    credentials: results.reused,
                    icon: "exclamationmark.triangle",
                    description: "These passwords are shared across multiple sites. If one site is compromised, all sites using this password are at risk.",
                    tint: .orange
                )
            }

            if !results.old.isEmpty {
                auditSection(
                    "Old Passwords",
                    credentials: results.old,
                    icon: "clock.badge.exclamationmark",
                    description: "These passwords haven't been changed in over 6 months. Consider updating them.",
                    tint: .yellow
                )
            }

            if results.isHealthy {
                Section {
                    Label("Your vault looks healthy!", systemImage: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("Your vault looks healthy. No security issues found.")
                }
            }
        }
        .refreshable { await runAudit() }
    }

    private func auditSection(
        _ title: String,
        credentials: [Credential],
        icon: String,
        description: String,
        tint: Color
    ) -> some View {
        Section {
            Text(description)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
                .accessibilityLabel(description)

            ForEach(credentials) { credential in
                NavigationLink {
                    CredentialDetailView(credential: credential)
                } label: {
                    HStack {
                        Image(systemName: icon)
                            .foregroundStyle(tint)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(credential.title)
                            Text(credential.username)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityLabel("\(title): \(credential.title), \(credential.username). \(description)")
            }
        } header: {
            Label(title, systemImage: icon)
                .foregroundStyle(tint)
        }
    }

    private func runAudit() async {
        guard let credentials = try? appModel.store.fetchCredentials() else { return }

        var decryptedPasswords: [UUID: String] = [:]
        for credential in credentials {
            decryptedPasswords[credential.id] = try? appModel.store.decrypt(credential.encryptedPassword)
        }

        let weakCredentials = credentials.filter { c in
            guard let pwd = decryptedPasswords[c.id] else { return false }
            return PasswordGenerator.strength(of: pwd) == .weak
        }

        let passwordGroups = Dictionary(grouping: credentials) { decryptedPasswords[$0.id] ?? "" }
        let reusedCredentials = credentials.filter { c in
            guard let pwd = decryptedPasswords[c.id], !pwd.isEmpty else { return false }
            return (passwordGroups[pwd]?.count ?? 0) > 1
        }

        let sixMonthsAgo = Date.now.addingTimeInterval(-60 * 60 * 24 * 180)
        let oldCredentials = credentials.filter { $0.updatedAt < sixMonthsAgo }

        auditResults = AuditResults(
            total: credentials.count,
            weak: weakCredentials,
            reused: reusedCredentials,
            old: oldCredentials
        )
    }
}

private struct AuditSummarySection: View {
    let results: AuditResults

    var body: some View {
        Section {
            HStack(spacing: 24) {
                AuditStat(count: results.weak.count, label: "Weak", icon: "xmark.shield", color: .red)
                AuditStat(count: results.reused.count, label: "Reused", icon: "exclamationmark.triangle", color: .orange)
                AuditStat(count: results.old.count, label: "Old", icon: "clock", color: .yellow)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } header: {
            Text("\(results.total) credentials scanned")
        }
    }
}

private struct AuditStat: View {
    let count: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(count > 0 ? color : .secondary)
            Text("\(count)")
                .font(.title2.bold())
                .foregroundStyle(count > 0 ? color : .secondary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) \(label.lowercased()) password\(count == 1 ? "" : "s")")
    }
}

struct AuditResults {
    let total: Int
    let weak: [Credential]
    let reused: [Credential]
    let old: [Credential]

    var isHealthy: Bool { weak.isEmpty && reused.isEmpty && old.isEmpty }
}
