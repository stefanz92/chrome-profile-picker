import AppKit
import SwiftUI

/// Borderless floating panel that takes keyboard focus and hands key presses to a handler first.
final class PickerPanel: NSPanel {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, onKeyDown?(event) == true { return }
        super.sendEvent(event)
    }
}

/// Shows the profile picker at the mouse cursor for incoming links and opens the chosen profile.
final class ProfilePickerController: NSObject, NSWindowDelegate {
    private static let lastProfileKey = "lastProfileDirectory"
    private static let cornerRadius: CGFloat = 12

    private let state = PickerState()
    private let siteRules = SiteRuleStore.shared
    private var pendingURLs: [URL] = []
    private var profiles: [ChromeProfile] = []
    private var isPresenting = false

    private lazy var hostingView = NSHostingView(rootView: makeView())
    private lazy var panel = makePanel()

    /// Opens links covered by a site rule and shows the picker for the rest; holding Option always shows the picker.
    func present(_ urls: [URL]) {
        let profiles = Chrome.loadProfiles()
        let unmatchedURLs = NSEvent.modifierFlags.contains(.option) ? urls : openUsingSiteRules(urls, profiles: profiles)
        guard !unmatchedURLs.isEmpty else { return }

        if isPresenting {
            pendingURLs += unmatchedURLs
            refresh(reposition: false)
            return
        }

        guard profiles.count > 1 else {
            Chrome.open(unmatchedURLs, in: profiles.first)
            return
        }

        self.profiles = profiles
        pendingURLs = unmatchedURLs
        let lastProfile = UserDefaults.standard.string(forKey: Self.lastProfileKey)
        state.selectedIndex = profiles.firstIndex { $0.id == lastProfile } ?? 0
        state.remembersSite = false
        isPresenting = true

        refresh(reposition: true)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        dismiss()
    }

    /// Opens every link that matches a site rule in that rule's profile and returns the links that matched none.
    private func openUsingSiteRules(_ urls: [URL], profiles: [ChromeProfile]) -> [URL] {
        var unmatchedURLs: [URL] = []
        var urlsByProfileID: [String: [URL]] = [:]
        for url in urls {
            if let profileID = siteRules.profileID(for: url), profiles.contains(where: { $0.id == profileID }) {
                urlsByProfileID[profileID, default: []].append(url)
            } else {
                unmatchedURLs.append(url)
            }
        }
        for profile in profiles {
            if let urls = urlsByProfileID[profile.id] { Chrome.open(urls, in: profile) }
        }
        return unmatchedURLs
    }

    /// Domain shared by all pending links, which the "always use" option can save a rule for.
    private var pendingSiteDomain: String? {
        let domains = Set(pendingURLs.map { SiteRuleStore.normalizedDomain($0.host() ?? "") })
        guard domains.count == 1, let domain = domains.first else { return nil }
        return domain
    }

    private func pick(_ profile: ChromeProfile) {
        let urls = pendingURLs
        UserDefaults.standard.set(profile.id, forKey: Self.lastProfileKey)
        if state.remembersSite, let domain = pendingSiteDomain {
            siteRules.setRule(domain: domain, profileID: profile.id)
        }
        dismiss()
        Chrome.open(urls, in: profile)
    }

    private func cancel() {
        dismiss()
        // Hiding hands focus back to the app the link came from.
        NSApp.hide(nil)
    }

    private func dismiss() {
        guard isPresenting else { return }
        isPresenting = false
        pendingURLs = []
        panel.orderOut(nil)
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53: // escape
            cancel()
        case 36, 76: // return, keypad enter
            if profiles.indices.contains(state.selectedIndex) { pick(profiles[state.selectedIndex]) }
        case 125, 48: // down arrow, tab
            state.selectedIndex = (state.selectedIndex + 1) % profiles.count
        case 126: // up arrow
            state.selectedIndex = (state.selectedIndex - 1 + profiles.count) % profiles.count
        default:
            let character = event.charactersIgnoringModifiers?.lowercased()
            if character == "a", pendingSiteDomain != nil {
                state.remembersSite.toggle()
                return true
            }
            guard let number = character.flatMap(Int.init),
                  (1...9).contains(number), number <= profiles.count
            else { return false }
            pick(profiles[number - 1])
        }
        return true
    }

    private func refresh(reposition: Bool) {
        hostingView.rootView = makeView()
        let size = hostingView.fittingSize
        let frame = reposition ? frameNearMouse(for: size) : NSRect(origin: panel.frame.origin, size: size)
        panel.setFrame(frame, display: true)
        panel.invalidateShadow()
    }

    private func frameNearMouse(for size: NSSize) -> NSRect {
        let mouse = NSEvent.mouseLocation
        var origin = NSPoint(x: mouse.x - size.width / 2, y: mouse.y - size.height + 16)
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
            origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)
        }
        return NSRect(origin: origin, size: size)
    }

    private func makeView() -> PickerView {
        PickerView(urls: pendingURLs, profiles: profiles, siteDomain: pendingSiteDomain, state: state) { [weak self] profile in
            self?.pick(profile)
        }
    }

    private func makePanel() -> PickerPanel {
        let panel = PickerPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.onKeyDown = { [weak self] event in self?.handleKey(event) ?? false }

        let background = NSVisualEffectView()
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.maskImage = Self.roundedMask(radius: Self.cornerRadius)
        panel.contentView = background

        hostingView.autoresizingMask = [.width, .height]
        background.addSubview(hostingView)
        return panel
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}
