import assert from 'node:assert/strict'
import { test } from 'node:test'
import { shutdownCommand } from '../src/machine.ts'

test('shutdown: the daemons are stopped as tower down does, and only then is the distro terminated', () => {
  const { file, args } = shutdownCommand('/usr/bin/node', '/home/u/the-tower', 'Ubuntu')
  const [flag, script, ...positional] = args
  assert.equal(file, 'bash')
  assert.equal(flag, '-c')
  assert.deepEqual(positional, ['/usr/bin/node', '/home/u/the-tower', 'Ubuntu'])
  const stop = script.indexOf('"$1/src/cli.ts" down')
  const terminate = script.indexOf('wsl.exe --terminate "$2"')
  assert.ok(script.startsWith('sleep ') && stop > 0 && terminate > stop, script)
  assert.match(script.slice(stop, terminate), /^"\$1\/src\/cli.ts" down; \/mnt\/c\/Windows\/System32\//)
})
