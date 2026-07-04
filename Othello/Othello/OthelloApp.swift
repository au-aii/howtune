import FirebaseCore
import SwiftUI

@main
struct OthelloApp: App {
    init() {
        FirebaseApp.configure()
        UITabBar.appearance().isHidden = true
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
