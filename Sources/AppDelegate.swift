import AppKit

/// Routes incoming links to the profile picker and shows settings when the app is opened directly.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let picker = ProfilePickerController()
    private let settings = SettingsWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()
        let isOpenedDirectly = notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool ?? true
        if isOpenedDirectly { settings.show() }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        picker.present(urls)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settings.show()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Invisible menu so Cmd+W and Cmd+Q work in this menu-bar-less app.
    private func makeMainMenu() -> NSMenu {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(withTitle: "Quit Chrome Profile Picker", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        let mainMenu = NSMenu()
        mainMenu.addItem(appMenuItem)
        return mainMenu
    }
}
