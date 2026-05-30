/// A user-facing CLI failure: a message plus actionable suggestions.
///
/// Mirrors the original `CliError` — thrown from parsing/validation and rendered
/// by the executable as `error: <message>` followed by bulleted suggestions.
public struct CliError: Error, Equatable {
    public let message: String
    public let suggestions: [String]

    public init(_ message: String, _ suggestions: [String] = []) {
        self.message = message
        self.suggestions = suggestions
    }
}
