import Testing
@testable import CommitKit

private let defaultConfig = CommitConfig(
    types: CommitDefaults.types,
    maxLength: CommitDefaults.maxLength)

private let scopedConfig = CommitConfig(
    types: CommitDefaults.types,
    scopes: [
        "apps": ["portal", "governance"],
        "layers": ["client", "server", "api"],
        "infra": ["ci", "docker"],
        "tools": ["scripts"],
    ],
    maxLength: CommitDefaults.maxLength)

/// Assert that validation does not throw.
private func expectValid(_ message: String, _ config: CommitConfig) {
    #expect(throws: Never.self) {
        try CommitValidator.validate(message, config: config)
    }
}

/// Assert that validation throws a `CliError` whose message contains `substring`.
private func expectInvalid(_ message: String, _ config: CommitConfig, contains substring: String) {
    do {
        try CommitValidator.validate(message, config: config)
        Issue.record("expected validation to throw for \"\(message)\"")
    } catch let error as CliError {
        #expect(error.message.contains(substring),
                "\"\(error.message)\" should contain \"\(substring)\"")
    } catch {
        Issue.record("expected CliError, got \(error)")
    }
}

/// Assert that validation throws any `CliError`.
private func expectInvalid(_ message: String, _ config: CommitConfig) {
    #expect(throws: CliError.self) {
        try CommitValidator.validate(message, config: config)
    }
}

@Suite("CommitValidator — valid messages")
struct CommitValidatorValidTests {
    @Test("all default types accepted", arguments: CommitDefaults.types)
    func allDefaultTypes(type: String) {
        expectValid("\(type): do something", defaultConfig)
    }

    @Test("message with valid scope")
    func validScope() {
        expectValid("feat(portal): add feature", scopedConfig)
    }

    @Test("all scope categories accepted")
    func allScopeCategories() {
        expectValid("feat(governance): add feature", scopedConfig)
        expectValid("fix(api): fix endpoint", scopedConfig)
        expectValid("ci(docker): update image", scopedConfig)
        expectValid("chore(scripts): tweak job", scopedConfig)
    }

    @Test("message at max length")
    func messageAtMaxLength() {
        let msg = "feat: " + String(repeating: "a", count: CommitDefaults.maxLength - 6)
        expectValid(msg, defaultConfig)
    }

    @Test("scope allowed when no scopes configured")
    func scopeAllowedWhenNoneConfigured() {
        expectValid("feat(anything): add feature", defaultConfig)
    }
}

@Suite("CommitValidator — invalid type")
struct CommitValidatorInvalidTypeTests {
    @Test("unknown type")
    func unknownType() {
        expectInvalid("foo: do something", defaultConfig)
    }

    @Test("suggestions for similar types")
    func similarTypes() {
        expectInvalid("fea: do something", defaultConfig)
    }
}

@Suite("CommitValidator — invalid scope")
struct CommitValidatorInvalidScopeTests {
    @Test("unknown scope when scopes configured")
    func unknownScope() {
        expectInvalid("feat(unknown): add feature", scopedConfig)
    }

    @Test("includes allowed scopes in suggestion")
    func includesAllowedScopes() {
        expectInvalid("feat(unknown): add feature", scopedConfig)
    }
}

@Suite("CommitValidator — invalid description")
struct CommitValidatorInvalidDescriptionTests {
    @Test("uppercase start")
    func uppercaseStart() {
        expectInvalid("feat: Add feature", defaultConfig, contains: "lowercase")
    }

    @Test("non-ASCII uppercase start is also rejected")
    func nonASCIIUppercaseStart() {
        expectInvalid("feat: Éclair support", defaultConfig, contains: "lowercase")
    }

    @Test("a digit-leading description is allowed")
    func digitStartAllowed() {
        expectValid("perf: 2x faster startup", defaultConfig)
    }

    @Test("trailing period")
    func trailingPeriod() {
        expectInvalid("feat: add feature.", defaultConfig, contains: "punctuation")
    }

    @Test("trailing exclamation")
    func trailingExclamation() {
        expectInvalid("feat: add feature!", defaultConfig, contains: "punctuation")
    }

    @Test("trailing comma")
    func trailingComma() {
        expectInvalid("feat: add feature,", defaultConfig, contains: "punctuation")
    }

    @Test("trailing semicolon")
    func trailingSemicolon() {
        expectInvalid("feat: add feature;", defaultConfig, contains: "punctuation")
    }

    @Test("trailing colon")
    func trailingColon() {
        expectInvalid("feat: add feature:", defaultConfig, contains: "punctuation")
    }
}

@Suite("CommitValidator — message length")
struct CommitValidatorLengthTests {
    @Test("exceeds max length")
    func exceedsMaxLength() {
        let msg = "feat: " + String(repeating: "a", count: CommitDefaults.maxLength)
        expectInvalid(msg, defaultConfig, contains: "exceeds")
    }
}

@Suite("CommitValidator — custom config")
struct CommitValidatorCustomConfigTests {
    @Test("custom types")
    func customTypes() {
        let config = CommitConfig(types: ["add", "remove"], maxLength: 72)
        expectValid("add: new thing", config)
        expectInvalid("feat: new thing", config)
    }

    @Test("custom max length")
    func customMaxLength() {
        let config = CommitConfig(types: CommitDefaults.types, maxLength: 50)
        let msg = "feat: " + String(repeating: "a", count: 50)
        expectInvalid(msg, config, contains: "exceeds")
    }
}
