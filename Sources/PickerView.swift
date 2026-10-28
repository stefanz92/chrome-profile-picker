import SwiftUI

/// Picker state shared between keyboard handling and the view.
final class PickerState: ObservableObject {
    @Published var selectedIndex = 0
    @Published var remembersSite = false
}

/// Compact list of Chrome profiles to open the pending links with.
struct PickerView: View {
    let urls: [URL]
    let profiles: [ChromeProfile]
    /// Domain the "always use" option saves a rule for; nil hides the option.
    let siteDomain: String?
    @ObservedObject var state: PickerState
    let onPick: (ChromeProfile) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(linkSummary)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .padding(.bottom, 4)
                .help(urls.map(\.absoluteString).joined(separator: "\n"))

            ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                ProfileRow(
                    profile: profile,
                    shortcut: index < 9 ? "\(index + 1)" : nil,
                    isSelected: index == state.selectedIndex
                )
                .contentShape(Rectangle())
                .onHover { isHovering in
                    if isHovering { state.selectedIndex = index }
                }
                .onTapGesture { onPick(profile) }
            }

            if let siteDomain {
                Divider()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                HStack {
                    Toggle(isOn: $state.remembersSite) {
                        Text("Always use for \(siteDomain)")
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .toggleStyle(.checkbox)
                    .focusable(false)
                    Spacer(minLength: 8)
                    KeyCap(label: "A", isHighlighted: false)
                }
                .font(.system(size: 11))
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
        }
        .padding(6)
        .frame(width: 290)
    }

    private var linkSummary: String {
        guard let first = urls.first else { return "" }
        let label: String
        if first.isFileURL {
            label = first.lastPathComponent
        } else {
            let host = (first.host() ?? "").replacingOccurrences(of: "www.", with: "", options: .anchored)
            let path = first.path() == "/" ? "" : first.path()
            label = host.isEmpty ? first.absoluteString : host + path
        }
        return urls.count > 1 ? "\(label)  +\(urls.count - 1) more" : label
    }
}

/// One selectable profile line with avatar, name, email and shortcut key.
struct ProfileRow: View {
    let profile: ChromeProfile
    let shortcut: String?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ProfileAvatar(profile: profile, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.name)
                    .font(.system(size: 13, weight: .semibold))
                if let email = profile.email {
                    Text(email)
                        .font(.system(size: 11))
                        .opacity(isSelected ? 0.85 : 0.6)
                }
            }
            .lineLimit(1)
            Spacer(minLength: 8)
            if let shortcut {
                KeyCap(label: shortcut, isHighlighted: isSelected)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
    }
}

/// Small rounded label showing a keyboard shortcut.
struct KeyCap: View {
    let label: String
    let isHighlighted: Bool

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .frame(width: 18, height: 18)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHighlighted ? Color.white.opacity(0.22) : Color.primary.opacity(0.08))
            )
    }
}

/// Circular profile picture, falling back to the first letter on the profile color.
struct ProfileAvatar: View {
    let profile: ChromeProfile
    let size: CGFloat

    var body: some View {
        Group {
            if let avatar = profile.avatar {
                Image(nsImage: avatar)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(nsColor: profile.color)
                    Text(profile.name.prefix(1).uppercased())
                        .font(.system(size: size * 0.45, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
