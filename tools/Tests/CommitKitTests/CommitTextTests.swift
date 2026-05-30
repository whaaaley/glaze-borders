import Testing
@testable import CommitKit

@Suite("CommitText.subjectLine")
struct CommitTextTests {
    @Test("a single-line message is its own subject")
    func singleLine() {
        #expect(CommitText.subjectLine("feat: add thing") == "feat: add thing")
    }

    @Test("trims surrounding whitespace")
    func trims() {
        #expect(CommitText.subjectLine("  feat: add thing  ") == "feat: add thing")
    }

    @Test("skips leading blank lines")
    func skipsBlanks() {
        #expect(CommitText.subjectLine("\n\n  \nfeat: add thing\nbody") == "feat: add thing")
    }

    @Test("skips leading # comment lines (git commit template)")
    func skipsComments() {
        let msg = "# Please enter the commit message\n# Lines starting with # are ignored\nfeat: add thing"
        #expect(CommitText.subjectLine(msg) == "feat: add thing")
    }

    @Test("returns the subject, not a later body line")
    func subjectNotBody() {
        let msg = "fix: correct bug\n\nThis paragraph explains why."
        #expect(CommitText.subjectLine(msg) == "fix: correct bug")
    }

    @Test("empty or comment-only input yields an empty string")
    func emptyish() {
        #expect(CommitText.subjectLine("") == "")
        #expect(CommitText.subjectLine("\n\n  \n") == "")
        #expect(CommitText.subjectLine("# just a comment\n# another") == "")
    }
}
