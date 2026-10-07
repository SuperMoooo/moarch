import { describe, expect, test } from 'claude-code/testing'

import { changedPaths, inspect } from '../hooks/checks'
import type { Tree } from '../hooks/checks'

const clean: Tree = {
  pubspec: 'name: moarch\nversion: 9.7.3\n',
  versionDart: "const packageVersion = '9.7.3';\n",
  changelog: '# Changelog\n\n## 9.7.3\n\n- a fix\n',
  status: '',
  headPubspecDiff: '',
}

const texts = (tree: Tree) => inspect({ ...clean, ...tree }).checks.map(check => check.text)

describe('changedPaths', () => {
  test('reads modified, untracked and renamed entries', async () => {
    expect(changedPaths(' M lib/a.dart\n?? test/b_test.dart\nR  old.dart -> new.dart\n')).toEqual([
      'lib/a.dart',
      'test/b_test.dart',
      'new.dart',
    ])
  })
})

describe('inspect', () => {
  test('a clean tree has nothing to fix', async () => {
    expect(inspect(clean).checks).toEqual([])
    expect(inspect(clean).version).toBe('9.7.3')
  })

  test('flags version.dart out of sync with the pubspec', async () => {
    const found = texts({ ...clean, versionDart: "const packageVersion = '9.7.2';" })
    expect(found.some(text => text.includes('9.7.2'))).toBe(true)
  })

  test('asks for a new bump when the last commit bumped and lib changed', async () => {
    const bumped = { ...clean, status: ' M lib/src/runner.dart\n', headPubspecDiff: '-version: 9.7.2\n+version: 9.7.3\n' }
    expect(texts(bumped).some(text => text.includes('needs its own bump'))).toBe(true)
    expect(texts({ ...bumped, status: ' M lib/src/runner.dart\n M pubspec.yaml\n' }).some(text => text.includes('needs its own bump'))).toBe(false)
    expect(texts({ ...bumped, headPubspecDiff: '' }).some(text => text.includes('needs its own bump'))).toBe(false)
  })

  test('flags one stack changing without the other', async () => {
    const riverpod = { ...clean, status: ' M lib/src/templates/riverpod/notifier_templates.dart\n' }
    expect(texts(riverpod).some(text => text.includes('templates/bloc/ did not'))).toBe(true)
    const both = { ...clean, status: `${riverpod.status} M lib/src/templates/bloc/bloc_templates.dart\n` }
    expect(texts(both).some(text => text.includes('parity'))).toBe(false)
  })

  test('reminds about the agent guide until it changes too', async () => {
    const template = { ...clean, status: ' M lib/src/templates/core/core_templates.dart\n' }
    expect(texts(template).some(text => text.includes('agents_templates.dart'))).toBe(true)
    const guided = { ...clean, status: `${template.status} M lib/src/templates/misc/skills_templates.dart\n` }
    expect(texts(guided).some(text => text.includes('agents_templates.dart'))).toBe(false)
  })
})
