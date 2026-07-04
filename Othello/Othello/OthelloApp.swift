import FirebaseCore
import SwiftUI

@main
struct OthelloApp: App {
    @AppStorage("prefersDarkTheme") var prefersDarkTheme = true

    init() {
        FirebaseApp.configure()
        UITabBar.appearance().isHidden = true
        UITextField.appearance().textColor = .white
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(prefersDarkTheme ? .dark : .light)
        }
    }
}
