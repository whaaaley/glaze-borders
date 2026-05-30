import Testing
@testable import CommitKit

/// Assert that parsing `message` throws a `CliError` whose message contains `substring`.
private func expectParseThrows(_ message: String, contains substring: String) {
    do {
        _ = try CommitParser.parse(message)
        Issue.record("expected parse to throw for \"\(message)\"")
    } catch let error as CliError {
        #expect(error.message.contains(substring),
                "\"\(error.message)\" should contain \"\(substring)\"")
    } catch {
        Issue.record("expected CliError, got \(error)")
    }
}

@Suite("CommitParser — valid messages")
struct CommitParserValidTests {
    @Test("type and description")
    func typeAndDescription() throws {
        let result = try CommitParser.parse("feat: add new feature")
        #expect(result.type == "feat")
        #expect(result.scope == nil)
        #expect(result.description == "add new feature")
        #expect(result.raw == "feat: add new feature")
    }

    @Test("type with scope")
    func typeWithScope() throws {
        let result = try CommitParser.parse("fix(api): resolve timeout issue")
        #expect(result.type == "fix")
        #expect(result.scope == "api")
        #expect(result.description == "resolve timeout issue")
    }

    @Test("scope with hyphens")
    func scopeWithHyphens() throws {
        #expect(try CommitParser.parse("feat(my-scope): add feature").scope == "my-scope")
    }

    @Test("scope with camelCase")
    func scopeCamelCase() throws {
        #expect(try CommitParser.parse("feat(myScope): add feature").scope == "myScope")
    }

    @Test("scope with numbers")
    func scopeWithNumbers() throws {
        #expect(try CommitParser.parse("fix(api2): fix endpoint").scope == "api2")
    }

    @Test("trims whitespace")
    func trimsWhitespace() throws {
        let result = try CommitParser.parse("  feat: add feature  ")
        #expect(result.type == "feat")
        #expect(result.description == "add feature")
    }

    @Test("multi-word description")
    func multiWord() throws {
        let result = try CommitParser.parse("refactor: clean up the entire authentication flow")
        #expect(result.description == "clean up the entire authentication flow")
    }

    @Test("description with special characters")
    func specialChars() throws {
        let result = try CommitParser.parse("docs: update README with `code` blocks")
        #expect(result.description == "update README with `code` blocks")
    }

    @Test("description with colons")
    func descriptionWithColons() throws {
        let result = try CommitParser.parse("feat: add config: new options")
        #expect(result.description == "add config: new options")
    }
}

@Suite("CommitParser — invalid messages")
struct CommitParserInvalidTests {
    @Test("empty string")
    func emptyString() {
        expectParseThrows("", contains: "must not be empty")
        expectParseThrows("  ", contains: "must not be empty")
    }

    @Test("missing colon")
    func missingColon() {
        expectParseThrows("feat add feature", contains: "must contain a colon")
    }

    @Test("empty description")
    func emptyDescription() {
        expectParseThrows("feat:", contains: "description must not be empty")
        expectParseThrows("feat:   ", contains: "description must not be empty")
    }

    @Test("uppercase type")
    func uppercaseType() {
        expectParseThrows("Feat: add feature", contains: "only lowercase letters")
    }

    @Test("type with numbers")
    func typeWithNumbers() {
        expectParseThrows("feat2: add feature", contains: "only lowercase letters")
    }

    @Test("type with hyphens")
    func typeWithHyphens() {
        expectParseThrows("hot-fix: fix bug", contains: "only lowercase letters")
    }

    @Test("missing closing parenthesis")
    func missingClosingParen() {
        expectParseThrows("feat(api: fix bug", contains: "without closing parenthesis")
    }

    @Test("missing opening parenthesis")
    func missingOpeningParen() {
        expectParseThrows("feat api): fix bug", contains: "without opening parenthesis")
    }

    @Test("empty scope")
    func emptyScope() {
        expectParseThrows("feat(): add feature", contains: "must not be empty")
    }

    @Test("uppercase scope start")
    func uppercaseScopeStart() {
        expectParseThrows("feat(Api): add feature", contains: "start with a lowercase")
    }

    @Test("scope with spaces")
    func scopeWithSpaces() {
        expectParseThrows("feat(my scope): add feature", contains: "only contain letters")
    }

    @Test("scope with special characters")
    func scopeWithSpecialChars() {
        expectParseThrows("feat(my_scope): add feature", contains: "only contain letters")
    }

    @Test("scope starting with number")
    func scopeStartingWithNumber() {
        expectParseThrows("feat(2api): add feature", contains: "start with a lowercase")
    }

    @Test("scope starting with hyphen")
    func scopeStartingWithHyphen() {
        expectParseThrows("feat(-api): add feature", contains: "start with a lowercase")
    }
}
