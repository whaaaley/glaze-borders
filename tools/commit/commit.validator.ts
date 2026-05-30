import { type CommitConfig, getAllScopes } from './commit.config.ts'
import { CliError } from '../utils/error.utils.ts'
import { parseCommitMessage } from './commit.parser.ts'

export const validateCommitMessage = (message: string, config: CommitConfig): void => {
  const parsed = parseCommitMessage(message)
  if (!config.types.includes(parsed.type)) {
    throw new CliError(`Invalid commit type: "${parsed.type}"`, [
      `Valid types are: ${config.types.join(', ')}`,
    ])
  }

  const allowedScopes = getAllScopes(config)
  if (parsed.scope && allowedScopes && !allowedScopes.includes(parsed.scope)) {
    throw new CliError(`Invalid scope: "${parsed.scope}"`, [
      `Allowed scopes are: ${allowedScopes.join(', ')}`,
    ])
  }

  if (/^[A-Z]/.test(parsed.description)) {
    throw new CliError('Description must start with a lowercase letter', [
      `Change "${parsed.description}" to start with a lowercase letter`,
    ])
  }

  if (/[.!,;:]$/.test(parsed.description)) {
    throw new CliError('Description must not end with punctuation', [
      `Remove the trailing "${parsed.description.slice(-1)}" from the description`,
    ])
  }

  if (parsed.raw.length > config.maxLength) {
    throw new CliError(
      `Commit message exceeds ${config.maxLength} characters (${parsed.raw.length})`,
      ['Be more concise'],
    )
  }
}
