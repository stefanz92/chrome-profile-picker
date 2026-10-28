import AppKit
import SwiftUI

/// Window shown when the app is opened directly: default-browser status and quick profile launch.
final class SettingsWindowController {
    private lazy var window: NSWindow = {
        let hostingController = NSHostingController(rootView: SettingsView())
        // Lets the window grow and shrink with the list of site rules.
        hostingController.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = [.titled, .closable]
        window.title = "Chrome Profile Picker"
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }()

    /// Brings the settings window to the front.
    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

/// Default-browser status, usage hints, the list of profiles and the site rules.
struct SettingsView: View {
    @State private var profiles = Chrome.loadProfiles()
    @State private var isDefaultBrowser = DefaultBrowser.isThisApp
    @ObservedObject private var siteRules = SiteRuleStore.shared
    @State private var newRuleDomain = ""
    @State private var newRuleProfileID = Chrome.loadProfiles().first?.id ?? ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chrome Profile Picker")
                        .font(.title3.weight(.semibold))
                    Text("Choose a Chrome profile every time you open a link.")
                        .foregroundStyle(.secondary)
                }
            }

            defaultBrowserStatus

            VStack(alignment: .leading, spacing: 6) {
                Text("Profiles")
                    .font(.headline)
                ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                    HStack(spacing: 10) {
                        ProfileAvatar(profile: profile, size: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(profile.name)
                            if let email = profile.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text("key \(index + 1)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Button("Open") { Chrome.open([], in: profile) }
                    }
                }
                if profiles.isEmpty {
                    Text("No Chrome profiles found.")
                        .foregroundStyle(.secondary)
                }
            }

            siteRulesSection

            Text("When you open a link, pick a profile with the mouse or press its number. Return opens the highlighted profile, A ticks \"Always use\", Esc cancels.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(20)
        .frame(width: 400)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
    }

    @ViewBuilder
    private var defaultBrowserStatus: some View {
        if isDefaultBrowser {
            Label("This is your default browser", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            HStack {
                Label("Not your default browser yet", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.orange)
                Spacer()
                Button("Make Default Browser") {
                    DefaultBrowser.makeThisApp(completion: refresh)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var siteRulesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Site rules")
                .font(.headline)
            Text("Links to these sites and their subdomains skip the picker. Hold ⌥ while opening a link to choose anyway.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(siteRules.rules) { rule in
                HStack(spacing: 8) {
                    Text(rule.domain)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    if let profile = profiles.first(where: { $0.id == rule.profileID }) {
                        ProfileAvatar(profile: profile, size: 18)
                        Text(profile.name)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Profile removed")
                            .foregroundStyle(.red)
                    }
                    Button {
                        siteRules.removeRule(rule)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Remove rule")
                }
            }

            HStack(spacing: 8) {
                TextField("example.com", text: $newRuleDomain)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addRule)
                Picker("Profile", selection: $newRuleProfileID) {
                    ForEach(profiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
                .labelsHidden()
                .fixedSize()
                Button("Add", action: addRule)
                    .disabled(SiteRuleStore.normalizedDomain(newRuleDomain) == nil || newRuleProfileID.isEmpty)
            }
        }
    }

    private func addRule() {
        guard !newRuleProfileID.isEmpty else { return }
        siteRules.setRule(domain: newRuleDomain, profileID: newRuleProfileID)
        newRuleDomain = ""
    }

    private func refresh() {
        profiles = Chrome.loadProfiles()
        isDefaultBrowser = DefaultBrowser.isThisApp
        if !profiles.contains(where: { $0.id == newRuleProfileID }) {
            newRuleProfileID = profiles.first?.id ?? ""
        }
    }
}
