import { CliError } from '../utils/error.utils.ts'

export type ParsedCommitMessage = {
  type: string
  scope?: string
  description: string
  raw: string
}

type PrefixParts = {
  type: string
  scope?: string
}

const parsePrefix = (prefix: string): PrefixParts => {
  const parenOpen = prefix.indexOf('(')
  const parenClose = prefix.indexOf(')')
  if (parenOpen === -1 && parenClose === -1) {
    return { type: prefix }
  }

  if (parenOpen === -1) {
    throw new CliError('Found closing parenthesis without opening parenthesis', [
      'Use the format: <type>(<scope>): <description>',
    ])
  }

  if (parenClose === -1) {
    throw new CliError('Found opening parenthesis without closing parenthesis', [
      'Use the format: <type>(<scope>): <description>',
    ])
  }

  if (parenClose < parenOpen) {
    throw new CliError('Mismatched parentheses in commit message', [
      'Use the format: <type>(<scope>): <description>',
    ])
  }

  if (parenClose !== prefix.length - 1) {
    throw new CliError('Unexpected characters after scope parentheses', [
      'Use the format: <type>(<scope>): <description>',
    ])
  }

  const type = prefix.slice(0, parenOpen)
  const scope = prefix.slice(parenOpen + 1, parenClose)
  if (!scope) {
    throw new CliError('Scope must not be empty when parentheses are present', [
      'Either provide a scope or remove the parentheses',
    ])
  }

  if (!/^[a-z]/.test(scope)) {
    throw new CliError('Scope must start with a lowercase letter', [
      `Change "${scope}" to start with a lowercase letter`,
    ])
  }

  if (!/^[a-z][a-zA-Z0-9-]*$/.test(scope)) {
    throw new CliError('Scope must only contain letters, numbers, and hyphens', [
      `Change "${scope}" to use only letters, numbers, and hyphens`,
    ])
  }

  return { type, scope }
}

export const parseCommitMessage = (message: string): ParsedCommitMessage => {
  const trimmed = message.trim()
  if (!trimmed) {
    throw new CliError('Commit message must not be empty', [
      'Provide a message in the format: <type>[(<scope>)]: <description>',
    ])
  }

  const colonIndex = trimmed.indexOf(':')
  if (colonIndex === -1) {
    throw new CliError('Commit message must contain a colon separator', [
      'Use the format: <type>[(<scope>)]: <description>',
      `Example: feat: ${trimmed}`,
    ])
  }

  const prefix = trimmed.slice(0, colonIndex)
  const description = trimmed.slice(colonIndex + 1).trim()
  const { type, scope } = parsePrefix(prefix)

  if (!type) {
    throw new CliError('Commit type must not be empty', [
      'Provide a type before the colon',
      'Example: feat: add new feature',
    ])
  }

  if (!/^[a-z]+$/.test(type)) {
    throw new CliError('Commit type must contain only lowercase letters', [
      `Change "${type}" to use only lowercase letters`,
      'Valid types include: feat, fix, docs, style, refactor, test, chore',
    ])
  }

  if (!description) {
    throw new CliError('Commit description must not be empty', [
      'Provide a description after the colon',
      `Example: ${prefix}: add new feature`,
    ])
  }

  return { type, scope, description, raw: trimmed }
}
