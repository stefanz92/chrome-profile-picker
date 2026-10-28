import AppKit

/// Checks and changes whether this app is the system's default web browser.
enum DefaultBrowser {
    /// Whether http and https links currently open with this app.
    static var isThisApp: Bool {
        isThisApp(handling: "http") && isThisApp(handling: "https")
    }

    /// Asks macOS to make this app the default browser; macOS shows its own confirmation dialog.
    static func makeThisApp(completion: @escaping () -> Void) {
        setHandler(for: "http") {
            guard !isThisApp(handling: "https") else { return completion() }
            setHandler(for: "https", completion: completion)
        }
    }

    private static func isThisApp(handling scheme: String) -> Bool {
        guard let url = URL(string: "\(scheme)://example.com"),
              let handler = NSWorkspace.shared.urlForApplication(toOpen: url)
        else { return false }
        return Bundle(url: handler)?.bundleIdentifier == Bundle.main.bundleIdentifier
    }

    private static func setHandler(for scheme: String, completion: @escaping () -> Void) {
        NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: scheme) { _ in
            DispatchQueue.main.async(execute: completion)
        }
    }
}
