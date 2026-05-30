/// Pure text helpers shared by the CLI and tests — no I/O, stdlib only.
public enum CommitText {
    /// The subject line of a raw commit message: the first line that is neither
    /// blank nor a `#` comment, trimmed. Git writes the subject first and appends
    /// `#`-comments (and a blank line then the body), so this is the line the
    /// conventional-commit rules apply to. Returns `""` when there is no such line.
    public static func subjectLine(_ message: String) -> String {
        for rawLine in message.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = trim(String(rawLine))
            if !line.isEmpty && !line.hasPrefix("#") { return line }
        }
        return ""
    }

    /// Trim leading/trailing whitespace and newlines (stdlib-only).
    static func trim(_ s: String) -> String {
        String(s.drop { $0.isWhitespace }.reversed().drop { $0.isWhitespace }.reversed())
    }
}
