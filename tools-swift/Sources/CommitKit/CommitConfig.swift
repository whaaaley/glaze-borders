/// Conventional-commit vocabulary. Defaults from https://www.conventionalcommits.org/.
public enum CommitDefaults {
    public static let types: [String] = [
        "feat",
        "fix",
        "build",
        "chore",
        "ci",
        "docs",
        "style",
        "refactor",
        "perf",
        "test",
        "revert",
    ]

    public static let maxLength = 72
}

public struct CommitConfig: Equatable, Sendable {
    public var types: [String]
    /// Categorised allowed scopes; `nil` means any scope is permitted.
    public var scopes: [String: [String]]?
    public var maxLength: Int

    public init(types: [String], scopes: [String: [String]]? = nil, maxLength: Int) {
        self.types = types
        self.scopes = scopes
        self.maxLength = maxLength
    }

    public static let `default` = CommitConfig(
        types: CommitDefaults.types,
        maxLength: CommitDefaults.maxLength)

    /// Flatten every configured scope category, or `nil` when no scopes are set.
    public var allScopes: [String]? {
        guard let scopes else { return nil }
        return scopes.values.flatMap { $0 }
    }

    /// The active configuration. Kept as a function to mirror `loadConfig()` and
    /// leave room for reading project config later.
    public static func load() -> CommitConfig { .default }
}
