import SwiftUI

@main
struct LifeOSApp: App {
    @StateObject private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(services)
        }
    }
}
