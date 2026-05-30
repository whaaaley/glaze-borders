public struct ParsedCommitMessage: Equatable {
    public let type: String
    public let scope: String?
    public let description: String
    public let raw: String
}

public enum CommitParser {
    private struct PrefixParts {
        let type: String
        let scope: String?
    }

    /// Parse the `<type>[(<scope>)]` portion before the colon.
    private static func parsePrefix(_ prefix: String) throws -> PrefixParts {
        let parenOpen = prefix.firstIndex(of: "(")
        let parenClose = prefix.firstIndex(of: ")")

        if parenOpen == nil && parenClose == nil {
            return PrefixParts(type: prefix, scope: nil)
        }

        if parenOpen == nil {
            throw CliError("Found closing parenthesis without opening parenthesis", [
                "Use the format: <type>(<scope>): <description>",
            ])
        }

        guard let open = parenOpen, let close = parenClose else {
            // Unreachable: the nil cases are handled above. Restated as a guard so
            // the bindings are non-optional without a force-unwrap.
            throw CliError("Found opening parenthesis without closing parenthesis", [
                "Use the format: <type>(<scope>): <description>",
            ])
        }

        if close < open {
            throw CliError("Mismatched parentheses in commit message", [
                "Use the format: <type>(<scope>): <description>",
            ])
        }

        if prefix.index(after: close) != prefix.endIndex {
            throw CliError("Unexpected characters after scope parentheses", [
                "Use the format: <type>(<scope>): <description>",
            ])
        }

        let type = String(prefix[prefix.startIndex..<open])
        let scope = String(prefix[prefix.index(after: open)..<close])

        if scope.isEmpty {
            throw CliError("Scope must not be empty when parentheses are present", [
                "Either provide a scope or remove the parentheses",
            ])
        }

        if !startsWithLowercase(scope) {
            throw CliError("Scope must start with a lowercase letter", [
                "Change \"\(scope)\" to start with a lowercase letter",
            ])
        }

        if !isValidScope(scope) {
            throw CliError("Scope must only contain letters, numbers, and hyphens", [
                "Change \"\(scope)\" to use only letters, numbers, and hyphens",
            ])
        }

        return PrefixParts(type: type, scope: scope)
    }

    public static func parse(_ message: String) throws -> ParsedCommitMessage {
        let trimmed = trim(message)
        if trimmed.isEmpty {
            throw CliError("Commit message must not be empty", [
                "Provide a message in the format: <type>[(<scope>)]: <description>",
            ])
        }

        guard let colonIndex = trimmed.firstIndex(of: ":") else {
            throw CliError("Commit message must contain a colon separator", [
                "Use the format: <type>[(<scope>)]: <description>",
                "Example: feat: \(trimmed)",
            ])
        }

        let prefix = String(trimmed[trimmed.startIndex..<colonIndex])
        let description = trim(String(trimmed[trimmed.index(after: colonIndex)...]))
        let parts = try parsePrefix(prefix)
        let type = parts.type

        if type.isEmpty {
            throw CliError("Commit type must not be empty", [
                "Provide a type before the colon",
                "Example: feat: add new feature",
            ])
        }

        if !isLowercaseLetters(type) {
            throw CliError("Commit type must contain only lowercase letters", [
                "Change \"\(type)\" to use only lowercase letters",
                "Valid types include: feat, fix, docs, style, refactor, test, chore",
            ])
        }

        if description.isEmpty {
            throw CliError("Commit description must not be empty", [
                "Provide a description after the colon",
                "Example: \(prefix): add new feature",
            ])
        }

        return ParsedCommitMessage(type: type, scope: parts.scope, description: description, raw: trimmed)
    }

    // MARK: - Character-class helpers (stdlib-only, no regex dependency)

    /// Trim leading/trailing whitespace and newlines — matches JS `String.trim()`.
    private static func trim(_ s: String) -> String {
        String(s.drop { $0.isWhitespace }.reversed().drop { $0.isWhitespace }.reversed())
    }

    /// `/^[a-z]+$/`
    private static func isLowercaseLetters(_ s: String) -> Bool {
        !s.isEmpty && s.allSatisfy { $0.isASCII && $0.isLowercase }
    }

    /// `/^[a-z]/`
    static func startsWithLowercase(_ s: String) -> Bool {
        guard let first = s.first else { return false }
        return first.isASCII && first.isLowercase
    }

    /// `/^[a-z][a-zA-Z0-9-]*$/` — assumes the lowercase-start check already passed.
    private static func isValidScope(_ s: String) -> Bool {
        guard startsWithLowercase(s) else { return false }
        return s.dropFirst().allSatisfy { c in
            (c.isASCII && (c.isLetter || c.isNumber)) || c == "-"
        }
    }
}
