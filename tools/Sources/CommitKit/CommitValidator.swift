public enum CommitValidator {
    private static let trailingPunctuation: Set<Character> = [".", "!", ",", ";", ":"]

    public static func validate(_ message: String, config: CommitConfig) throws {
        let parsed = try CommitParser.parse(message)

        if !config.types.contains(parsed.type) {
            throw CliError("Invalid commit type: \"\(parsed.type)\"", [
                "Valid types are: \(config.types.joined(separator: ", "))",
            ])
        }

        if let scope = parsed.scope, let allowed = config.allScopes, !allowed.contains(scope) {
            throw CliError("Invalid scope: \"\(scope)\"", [
                "Allowed scopes are: \(allowed.joined(separator: ", "))",
            ])
        }

        // Reject an uppercase first letter in ANY script (not just ASCII, so `É…`
        // is caught too). Digits/punctuation starts are intentionally allowed —
        // messages like "fix: 2x faster" are fine — so the message says "not start
        // with an uppercase letter" rather than claiming it must be lowercase.
        if let first = parsed.description.first, first.isUppercase {
            throw CliError("Description must start with a lowercase letter, not uppercase", [
                "Change \"\(parsed.description)\" to start with a lowercase letter",
            ])
        }

        if let last = parsed.description.last, trailingPunctuation.contains(last) {
            throw CliError("Description must not end with punctuation", [
                "Remove the trailing \"\(last)\" from the description",
            ])
        }

        // `raw` is the subject line (the CLI passes only the first line). Length is
        // a grapheme count, which is close enough to git's 72-column convention.
        if parsed.raw.count > config.maxLength {
            throw CliError(
                "Subject line exceeds \(config.maxLength) characters (\(parsed.raw.count))",
                ["Be more concise"])
        }
    }
}
