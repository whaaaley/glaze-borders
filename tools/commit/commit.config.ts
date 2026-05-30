// Conventional-commit vocabulary. Defaults from https://www.conventionalcommits.org/.
export const DEFAULT_TYPES: string[] = [
  'feat',
  'fix',
  'build',
  'chore',
  'ci',
  'docs',
  'style',
  'refactor',
  'perf',
  'test',
  'revert',
]

export const DEFAULT_MAX_LENGTH: number = 72

export type CommitConfig = {
  types: string[]
  scopes?: Record<string, string[]>
  maxLength: number
}

export const defaultConfig: CommitConfig = {
  types: DEFAULT_TYPES,
  maxLength: DEFAULT_MAX_LENGTH,
}

export const getAllScopes = (config: CommitConfig): string[] | undefined => {
  if (!config.scopes) {
    return undefined
  }

  return Object.values(config.scopes).flat()
}

export const loadConfig = (): CommitConfig => {
  return defaultConfig
}
