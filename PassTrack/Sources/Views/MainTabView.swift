import PassTrackKit
import SwiftUI

struct MainTabView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        TabView {
            Tab("Vault", systemImage: "lock.fill") {
                VaultListView()
            }
            Tab("Generator", systemImage: "key.fill") {
                PasswordGeneratorView()
            }
            Tab("Audit", systemImage: "shield.fill") {
                SecurityAuditView()
            }
            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }
        }
        .accessibilityElement(children: .contain)
    }
}
