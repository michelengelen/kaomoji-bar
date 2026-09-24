import SwiftUI

@main
struct KaomojiBarApp: App {
    init() {
        // Keep the app out of the Dock and the app switcher.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView()
        } label: {
            Text("ツ")
        }
        .menuBarExtraStyle(.window)
    }
}
