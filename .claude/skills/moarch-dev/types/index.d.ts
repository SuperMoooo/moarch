/** How much a check matters: `error` fails CI, `warn` breaks a rule, `info` is a reminder. */
export type MoarchDevLevel = 'error' | 'warn' | 'info'

/** One finding about the working tree. */
export type MoarchDevCheck = { level: MoarchDevLevel; text: string }

/** What the dashboard, the band and the status line draw. */
export type MoarchDevReport = {
  /** `version:` in pubspec.yaml. */
  version: string
  /** Paths `git status` reports as changed or untracked. */
  changed: string[]
  /** Whether the last commit changed the pubspec's `version:`. */
  isHeadBump: boolean
  checks: MoarchDevCheck[]
}

declare module 'claude-code' {
  interface PluginState {
    'moarch-dev': {
      report: MoarchDevReport | null
      isBandHidden: boolean
    }
  }
}
