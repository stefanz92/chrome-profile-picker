import AppKit

/// A Chrome profile as listed in Chrome's "Local State" file.
struct ChromeProfile: Identifiable {
    /// Profile directory name, e.g. "Default" or "Profile 2".
    let id: String
    let name: String
    let email: String?
    let color: NSColor
    let avatar: NSImage?
}

/// Reads the installed Chrome profiles and opens links in a chosen profile.
enum Chrome {
    static let bundleIdentifier = "com.google.Chrome"

    private static let dataDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Google/Chrome")

    /// Returns the visible profiles in Chrome's own order.
    static func loadProfiles() -> [ChromeProfile] {
        guard let data = try? Data(contentsOf: dataDirectory.appendingPathComponent("Local State")),
              let localState = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profileSection = localState["profile"] as? [String: Any],
              let infoCache = profileSection["info_cache"] as? [String: [String: Any]]
        else { return [] }

        let order = (profileSection["profiles_order"] as? [String]) ?? []
        let directories = order.filter { infoCache[$0] != nil }
            + infoCache.keys.filter { !order.contains($0) }.sorted()

        return directories.compactMap { directory in
            guard let info = infoCache[directory],
                  info["is_omitted_from_profile_list"] as? Bool != true,
                  info["is_ephemeral"] as? Bool != true
            else { return nil }

            let email = (info["user_name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            let colorValue = (info["profile_highlight_color"] as? Int) ?? (info["default_avatar_fill_color"] as? Int)
            let picture = dataDirectory.appendingPathComponent(directory).appendingPathComponent("Google Profile Picture.png")

            return ChromeProfile(
                id: directory,
                name: (info["name"] as? String) ?? directory,
                email: email,
                color: colorValue.map(color(fromARGB:)) ?? .systemBlue,
                avatar: NSImage(contentsOf: picture)
            )
        }
    }

    /// Opens the URLs in the given profile; without URLs it opens a new window for that profile.
    static func open(_ urls: [URL], in profile: ChromeProfile?) {
        guard let chromeURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            showError("Google Chrome could not be found on this Mac.")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        // A second Chrome process hands its arguments to the running one and exits, which is the only way to pick a profile.
        configuration.createsNewApplicationInstance = true
        configuration.arguments = (profile.map { ["--profile-directory=\($0.id)"] } ?? [])
            + urls.map { $0.isFileURL ? $0.path : $0.absoluteString }

        NSWorkspace.shared.openApplication(at: chromeURL, configuration: configuration) { _, error in
            guard let error else { return }
            DispatchQueue.main.async { showError(error.localizedDescription) }
        }
    }

    /// Converts Chrome's signed 32-bit ARGB integer into a color.
    private static func color(fromARGB value: Int) -> NSColor {
        let argb = UInt32(truncatingIfNeeded: value)
        return NSColor(
            srgbRed: CGFloat((argb >> 16) & 0xFF) / 255,
            green: CGFloat((argb >> 8) & 0xFF) / 255,
            blue: CGFloat(argb & 0xFF) / 255,
            alpha: 1
        )
    }

    private static func showError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Couldn't open Chrome"
        alert.informativeText = message
        alert.runModal()
    }
}
