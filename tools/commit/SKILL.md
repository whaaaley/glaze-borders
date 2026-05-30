Rule: run `cd tools && deno task install-hooks` once per fresh clone
Reason: registers the `commit-msg` hook so every `git commit` is validated automatically

Rule: validate commit messages via `cd tools && deno task commit '<message>'` before running `git commit`
Reason: enforce conventional commit format deterministically before the message reaches history

Rule: do not pass `--no-verify` to `git commit`
Reason: bypasses the validator hook and lets malformed messages reach history

Rule: pass `--file <path>` to validate the contents of a file
Reason: hook-friendly invocation for `.git/COMMIT_EDITMSG` and similar

Rule: pipe a message into `deno task commit` via stdin as an alternative input
Reason: supports piped workflows where the message comes from another command

Rule: iterate on the validator's suggestions until exit 0 before running `git commit`
Reason: each non-zero exit prints the rule that failed and the configured vocabulary

Rule: format messages as `<type>[(<scope>)]: <description>`
Reason: required by the parser

Rule: use only types and scopes accepted by the validator
Reason: the validator's error output names the configured vocabulary

Rule: start the description with a lowercase letter
Reason: conventional commit format

Rule: do not end the description with `.` `!` `,` `;` or `:`
Reason: conventional commit format

Rule: keep the total message within the validator's max length
Reason: conventional commit format

Rule: do not use the breaking-change indicator `!` (e.g. `feat!:` or `feat(scope)!:`)
Reason: the parser rejects it; use a `BREAKING CHANGE:` footer in the body instead

Rule: validate only the subject line, not multi-line bodies
Reason: the validator inspects the first line only
