import { expect, test } from 'claude-code/testing'

const FILES: Record<string, string> = {
  'pubspec.yaml': 'name: moarch\nversion: 9.7.3\n',
  'lib/src/version.dart': "const packageVersion = '9.7.2';\n",
  'CHANGELOG.md': '## 9.7.3\n',
}

const PANE = {
  title: 'moarch dev',
  isFocused: true,
  bodyColumns: 100,
  placement: 'dock',
  scroll: { offset: 0, bodyRows: 30 },
  view: {},
} as const

test('the pane shows the version and what to fix, on every surface', async ($, on) => {
  on('fs.read', ($, e) => {
    const path = Object.keys(FILES).find(name => e.path.replace(/\\/g, '/').endsWith(name))
    if (path === undefined) throw new Error(`ENOENT ${e.path}`)

    return { value: FILES[path]! }
  })
  on('process.run', ($, e) => ({
    value: {
      exitCode: 0,
      stdout: e.argv[1] === 'status' ? ' M lib/src/templates/riverpod/x.dart\n' : '',
      stderr: '',
      isStdoutTruncated: false,
      isStderrTruncated: false,
    },
  }))
  on('ui.open', () => ({ value: { isPlaced: true } }))
  on('ui.status', () => ({ value: undefined }))
  // The engine's own drawing, beneath the plugin's.
  on('ui.render', ($, e) => {
    const { Box } = $.ui.resolve(e)

    return <Box />
  })

  await $.command.run({
    command: 'moarch-dev',
    args: '',
    origin: { kind: 'composer' },
    presentation: { isFullscreen: false, columns: 120 },
  })

  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({
      plugin: 'moarch-dev',
      surface,
      component: 'Pane',
      requestId: 'moarch-dev',
      props: PANE,
    })
    expect(await ui.find({ type: 'Text', text: 'moarch 9.7.3' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /version\.dart is 9\.7\.2/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /keep the stacks at parity/ })).toBeDefined()
    await ui.unmount()
  }
})
