import SwiftUI
import PassTrackKit

@main
struct PassTrackApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentRootView()
                .environment(appModel)
                .onOpenURL { url in
                    appModel.handle(deepLink: url)
                }
        }
    }
}
