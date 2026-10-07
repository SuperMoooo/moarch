import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { MoarchDevLevel, MoarchDevReport } from '../types'
import { inspect } from './checks'

const PANE = 'moarch-dev'
const report = atom({ plugin: 'moarch-dev', key: 'report' } as const, null)
const isBandHidden = atom({ plugin: 'moarch-dev', key: 'isBandHidden' } as const, false)

const MARK: Record<MoarchDevLevel, string> = { error: '✗', warn: '!', info: '·' }
const COLOR: Record<MoarchDevLevel, 'error' | 'warning' | 'subtle'> = {
  error: 'error',
  warn: 'warning',
  info: 'subtle',
}

async function readOr($: EngineInterface, path: string): Promise<string> {
  try {
    return await $.fs.read(path)
  } catch {
    return ''
  }
}

async function git($: EngineInterface, args: string[]): Promise<string> {
  try {
    const ran = await $.process.run(['git', ...args], { timeoutMs: 10000 })

    return ran.exitCode === 0 ? ran.stdout : ''
  } catch {
    return ''
  }
}

/** What the session has cost, as /cost totals it; `n/a` where there is no ledger. */
async function costOf($: EngineInterface): Promise<string> {
  try {
    const usage = await $.session.usage()

    return usage.cost === undefined ? 'n/a' : `$${usage.cost.usd.toFixed(2)}`
  } catch {
    return 'n/a'
  }
}

/** Re-reads the tree, stores the report and puts its summary on the status line. */
async function refresh($: EngineInterface): Promise<MoarchDevReport | null> {
  const pubspec = await readOr($, 'pubspec.yaml')
  if (!/^name:\s*moarch\s*$/m.test(pubspec)) {
    return null
  }

  const found = inspect({
    pubspec,
    versionDart: await readOr($, 'lib/src/version.dart'),
    changelog: await readOr($, 'CHANGELOG.md'),
    status: await git($, ['status', '--porcelain', '-uall']),
    headPubspecDiff: await git($, ['show', '-U0', '--format=', 'HEAD', '--', 'pubspec.yaml']),
  })
  await update($, report, () => found)

  const loud = found.checks.filter(check => check.level !== 'info').length
  $.ui.status(loud === 0 ? `moarch ${found.version}` : `moarch ${found.version} · ${loud} to fix`)

  return found
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'moarch-dev',
      description: 'Show the release and template checks for this moarch checkout',
    })
    await refresh($)

    return next(e)
  })

  on('command.run', { command: 'moarch-dev' }, async $ => {
    await refresh($)
    await update($, isBandHidden, () => false)
    await $.ui.open({ id: PANE, title: 'moarch dev' })

    return { text: 'moarch dev pane opened.' }
  })

  on('turn.complete', async ($, e, next) => {
    const ran = await next(e)
    if (e.agentId === undefined) {
      await refresh($)
    }

    return ran
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const now = await read($, report)
    const loud = now?.checks.filter(check => check.level !== 'info') ?? []
    if (e.props.hasSurvey || loud.length === 0 || (await read($, isBandHidden))) {
      return next(e)
    }

    const { Box, Button, Text } = $.ui.resolve(e)
    const first = loud[0]!

    return (
      <Box>
        <Text color={COLOR[first.level]}>
          {MARK[first.level]} {first.text}
          {loud.length > 1 ? ` (+${loud.length - 1})` : ''}{' '}
        </Text>
        <Button
          key="details"
          label="Details"
          onPress={() => $.ui.open({ id: PANE, title: 'moarch dev' })}
        />
        <Button key="hide" label="Hide" onPress={() => update($, isBandHidden, () => true)} />
      </Box>
    )
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Button, Text } = $.ui.resolve(e)
    const now = await read($, report)
    const cost = await costOf($)

    if (now === null) {
      return <Text dimColor>Not a moarch checkout: pubspec.yaml does not name moarch.</Text>
    }

    const templates = now.changed.filter(path => path.startsWith('lib/src/templates/'))

    return (
      <Box flexDirection="column">
        <Text bold>moarch {now.version}</Text>
        <Text dimColor>
          {now.changed.length} changed file{now.changed.length === 1 ? '' : 's'}
          {templates.length > 0 ? `, ${templates.length} under templates/` : ''}
          {now.isHeadBump ? ' · last commit bumped the version' : ''} · session {cost}
        </Text>
        <Text> </Text>
        {now.checks.length === 0 && <Text color="success">✓ Nothing to fix before pushing</Text>}
        {now.checks.map(check => (
          <Text color={COLOR[check.level]}>
            {MARK[check.level]} {check.text}
          </Text>
        ))}
        <Text> </Text>
        <Box>
          <Button key="refresh" label="Refresh" onPress={() => refresh($)} />
        </Box>
        <Text dimColor>CI: dart format · dart analyze --fatal-infos · version sync · dart test · publish --dry-run</Text>
      </Box>
    )
  })
}
