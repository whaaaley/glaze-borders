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

        if let first = parsed.description.first, first.isASCII, first.isUppercase {
            throw CliError("Description must start with a lowercase letter", [
                "Change \"\(parsed.description)\" to start with a lowercase letter",
            ])
        }

        if let last = parsed.description.last, trailingPunctuation.contains(last) {
            throw CliError("Description must not end with punctuation", [
                "Remove the trailing \"\(last)\" from the description",
            ])
        }

        if parsed.raw.count > config.maxLength {
            throw CliError(
                "Commit message exceeds \(config.maxLength) characters (\(parsed.raw.count))",
                ["Be more concise"])
        }
    }
}
