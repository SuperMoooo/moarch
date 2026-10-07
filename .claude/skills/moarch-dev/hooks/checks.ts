import type { MoarchDevCheck, MoarchDevReport } from '../types'

/** What the checks read off the working tree. */
export type Tree = {
  pubspec: string
  versionDart: string
  changelog: string
  /** `git status --porcelain -uall` output. */
  status: string
  /** `git show -U0 --format= HEAD -- pubspec.yaml` output. */
  headPubspecDiff: string
}

const RIVERPOD = 'lib/src/templates/riverpod/'
const BLOC = 'lib/src/templates/bloc/'
const TEMPLATES = 'lib/src/templates/'
const GUIDE = [
  'lib/src/templates/misc/agents_templates.dart',
  'lib/src/templates/misc/skills_templates.dart',
]

/** The paths in `git status --porcelain` output, the new side of a rename. */
export function changedPaths(status: string): string[] {
  return status
    .split('\n')
    .filter(line => line.length > 3)
    .map(line => {
      const path = line.slice(3).trim()
      const arrow = path.indexOf(' -> ')
      const last = arrow === -1 ? path : path.slice(arrow + 4)

      return last.replace(/^"|"$/g, '')
    })
}

/** Reads the tree into the report the dashboard draws. */
export function inspect(tree: Tree): MoarchDevReport {
  const version = /^version:\s*(\S+)/m.exec(tree.pubspec)?.[1] ?? '?'
  const constant = /packageVersion\s*=\s*'([^']+)'/.exec(tree.versionDart)?.[1]
  const logged = /^## (\S+)/m.exec(tree.changelog)?.[1]
  const changed = changedPaths(tree.status)
  const isHeadBump = /^\+version:/m.test(tree.headPubspecDiff)
  const checks: MoarchDevCheck[] = []
  const touches = (prefix: string) => changed.some(path => path.startsWith(prefix))

  if (constant !== version) {
    checks.push({
      level: 'error',
      text: `pubspec.yaml is ${version} but lib/src/version.dart is ${constant ?? 'missing'}: CI fails`,
    })
  }
  if (logged !== version) {
    checks.push({
      level: 'warn',
      text: `CHANGELOG.md's newest entry is ${logged ?? 'missing'}, not ${version}`,
    })
  }

  const ships = changed.some(path => path.startsWith('lib/') || path === 'bin/main.dart')
  if (ships && isHeadBump && !changed.includes('pubspec.yaml')) {
    checks.push({
      level: 'warn',
      text: `The last commit already bumped to ${version}: this change needs its own bump (release skill)`,
    })
  }

  if (touches(RIVERPOD) !== touches(BLOC)) {
    const [did, didNot] = touches(RIVERPOD) ? ['riverpod', 'bloc'] : ['bloc', 'riverpod']
    checks.push({
      level: 'warn',
      text: `templates/${did}/ changed but templates/${didNot}/ did not: keep the stacks at parity`,
    })
  }

  const isTemplateChange = changed.some(
    path => path.startsWith(TEMPLATES) && !GUIDE.includes(path),
  )
  if (isTemplateChange && !GUIDE.some(path => changed.includes(path))) {
    checks.push({
      level: 'info',
      text: 'Templates changed: if a path, command or state pattern moved, update agents_templates.dart and skills_templates.dart too',
    })
  }

  return { version, changed, isHeadBump, checks }
}
