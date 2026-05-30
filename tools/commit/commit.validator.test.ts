import { expect } from '@std/expect'
import { describe, it } from '@std/testing/bdd'
import { type CommitConfig, DEFAULT_MAX_LENGTH, DEFAULT_TYPES } from './commit.config.ts'
import { CliError } from '../utils/error.utils.ts'
import { validateCommitMessage } from './commit.validator.ts'

const defaultConfig: CommitConfig = {
  types: DEFAULT_TYPES,
  maxLength: DEFAULT_MAX_LENGTH,
}

const scopedConfig: CommitConfig = {
  types: DEFAULT_TYPES,
  maxLength: DEFAULT_MAX_LENGTH,
  scopes: {
    apps: ['portal', 'governance'],
    layers: ['client', 'server', 'api'],
    infra: ['ci', 'docker'],
    tools: ['scripts'],
  },
}

describe('commit.validator', () => {
  describe('valid messages', () => {
    it('all default types accepted', () => {
      for (const type of DEFAULT_TYPES) {
        expect(() => validateCommitMessage(`${type}: do something`, defaultConfig)).not.toThrow()
      }
    })

    it('message with valid scope', () => {
      expect(() => validateCommitMessage('feat(portal): add feature', scopedConfig)).not.toThrow()
    })

    it('all scope categories accepted', () => {
      expect(() => validateCommitMessage('feat(governance): add feature', scopedConfig)).not.toThrow()
      expect(() => validateCommitMessage('fix(api): fix endpoint', scopedConfig)).not.toThrow()
      expect(() => validateCommitMessage('ci(docker): update image', scopedConfig)).not.toThrow()
      expect(() => validateCommitMessage('chore(scripts): tweak job', scopedConfig)).not.toThrow()
    })

    it('message at max length', () => {
      const msg = 'feat: ' + 'a'.repeat(DEFAULT_MAX_LENGTH - 6)
      expect(() => validateCommitMessage(msg, defaultConfig)).not.toThrow()
    })

    it('scope allowed when no scopes configured', () => {
      expect(() => validateCommitMessage('feat(anything): add feature', defaultConfig)).not.toThrow()
    })
  })

  describe('invalid type', () => {
    it('unknown type', () => {
      expect(() => validateCommitMessage('foo: do something', defaultConfig)).toThrow()
    })

    it('suggestions for similar types', () => {
      expect(() => validateCommitMessage('fea: do something', defaultConfig)).toThrow(CliError)
    })
  })

  describe('invalid scope', () => {
    it('unknown scope when scopes configured', () => {
      expect(() => validateCommitMessage('feat(unknown): add feature', scopedConfig)).toThrow()
    })

    it('includes allowed scopes in suggestion', () => {
      expect(() => validateCommitMessage('feat(unknown): add feature', scopedConfig)).toThrow(CliError)
    })
  })

  describe('invalid description', () => {
    it('uppercase start', () => {
      expect(() => validateCommitMessage('feat: Add feature', defaultConfig)).toThrow('lowercase')
    })

    it('trailing period', () => {
      expect(() => validateCommitMessage('feat: add feature.', defaultConfig)).toThrow('punctuation')
    })

    it('trailing exclamation', () => {
      expect(() => validateCommitMessage('feat: add feature!', defaultConfig)).toThrow('punctuation')
    })

    it('trailing comma', () => {
      expect(() => validateCommitMessage('feat: add feature,', defaultConfig)).toThrow('punctuation')
    })

    it('trailing semicolon', () => {
      expect(() => validateCommitMessage('feat: add feature;', defaultConfig)).toThrow('punctuation')
    })

    it('trailing colon', () => {
      expect(() => validateCommitMessage('feat: add feature:', defaultConfig)).toThrow('punctuation')
    })
  })

  describe('message length', () => {
    it('exceeds max length', () => {
      const msg = 'feat: ' + 'a'.repeat(DEFAULT_MAX_LENGTH)
      expect(() => validateCommitMessage(msg, defaultConfig)).toThrow('exceeds')
    })
  })

  describe('custom config', () => {
    it('custom types', () => {
      const config: CommitConfig = { types: ['add', 'remove'], maxLength: 72 }
      expect(() => validateCommitMessage('add: new thing', config)).not.toThrow()
      expect(() => validateCommitMessage('feat: new thing', config)).toThrow()
    })

    it('custom max length', () => {
      const config: CommitConfig = { types: DEFAULT_TYPES, maxLength: 50 }
      const msg = 'feat: ' + 'a'.repeat(50)
      expect(() => validateCommitMessage(msg, config)).toThrow('exceeds')
    })
  })
})
