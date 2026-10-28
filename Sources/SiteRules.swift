import Foundation

/// A remembered choice: links to this domain and its subdomains open in this profile.
struct SiteRule: Codable, Equatable, Identifiable {
    let domain: String
    let profileID: String

    var id: String { domain }
}

/// Persists site rules and finds the profile a link should open in.
final class SiteRuleStore: ObservableObject {
    static let shared = SiteRuleStore(defaults: .standard)
    private static let defaultsKey = "siteRules"

    @Published private(set) var rules: [SiteRule]
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        let data = defaults.data(forKey: Self.defaultsKey)
        rules = data.flatMap { try? JSONDecoder().decode([SiteRule].self, from: $0) } ?? []
    }

    /// Returns the profile directory of the most specific rule matching the link's host.
    func profileID(for url: URL) -> String? {
        guard let host = Self.normalizedDomain(url.host() ?? "") else { return nil }
        return rules
            .filter { host == $0.domain || host.hasSuffix("." + $0.domain) }
            .max { $0.domain.count < $1.domain.count }?
            .profileID
    }

    /// Adds the rule, replacing an existing rule for the same domain.
    func setRule(domain: String, profileID: String) {
        guard let domain = Self.normalizedDomain(domain) else { return }
        rules.removeAll { $0.domain == domain }
        rules.append(SiteRule(domain: domain, profileID: profileID))
        rules.sort { $0.domain < $1.domain }
        save()
    }

    /// Deletes the rule.
    func removeRule(_ rule: SiteRule) {
        rules.removeAll { $0 == rule }
        save()
    }

    /// Reduces input like "https://*.Example.com:8080/path" to "example.com"; nil when no domain is left.
    static func normalizedDomain(_ input: String) -> String? {
        var domain = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let schemeEnd = domain.range(of: "://") {
            domain = String(domain[schemeEnd.upperBound...])
        }
        domain = String(domain.prefix { !"/?#:".contains($0) })
        while let prefix = ["*.", ".", "www."].first(where: domain.hasPrefix) {
            domain.removeFirst(prefix.count)
        }
        while domain.hasSuffix(".") {
            domain.removeLast()
        }
        guard !domain.isEmpty, !domain.contains(where: { $0.isWhitespace || $0 == "*" }) else { return nil }
        return domain
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(rules), forKey: Self.defaultsKey)
    }
}
