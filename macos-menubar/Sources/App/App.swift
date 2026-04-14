import SwiftUI

@main
struct FileSandboxMenuBarApp: App {
    @StateObject private var store = JobStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(store: store)
        } label: {
            Image(systemName: store.iconName)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 18, weight: .medium))
        }
        .menuBarExtraStyle(.window)
    }
}
