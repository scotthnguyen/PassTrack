import PassTrackKit
import SwiftUI

struct ContentRootView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        if appModel.needsOnboarding {
            OnboardingView()
        } else if appModel.isLocked {
            LockScreenView()
        } else {
            MainTabView()
        }
    }
}
