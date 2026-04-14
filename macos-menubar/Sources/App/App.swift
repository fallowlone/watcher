import SwiftUI

@main
struct FileSandboxMenuBarApp: App {
    @StateObject private var store = JobStore()
    @StateObject private var settingsStore = SettingsStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(store: store, settingsStore: settingsStore)
        } label: {
            Image(systemName: store.iconName)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 18, weight: .medium))
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: settingsStore)
        }
    }
}
