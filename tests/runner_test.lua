--- Verify script arguments, duplicate guards, cancellation and terminal task states.
-- @script tests.runner_test
-- Test doubles keep these assertions independent of real apps and personal settings.

package.loaded['modules.config.personal'] = { data = {} }
package.path = './?.lua;./?/init.lua;' .. package.path
local done, launches, received, streaming = nil, 0, nil, nil
hs = {
  alert = { show = function() end },
  notify = {
    new = function()
      return { send = function() end }
    end,
  },
  task = {
    new = function(bin, cb, stream, args)
      assert(bin == '/bin/bash')
      launches = launches + 1
      done = cb
      streaming = stream
      received = args
      return {
        start = function()
          return true
        end,
      }
    end,
  },
  dialog = {
    blockAlert = function()
      return 'Cancelar'
    end,
  },
}
local r = require('modules.tasks.runner')
local job = { id = 'test', title = 'Test', script = '/tmp/example.sh', args = { 'a b', '$(not-executed)' } }
assert(r.run(job))
assert(r.isRunning('test'))
assert(not r.run(job))
assert(launches == 1)
assert(received[2] == 'a b' and received[3] == '$(not-executed)')
done(0, '', '')
assert(not r.isRunning('test'))
assert(r.states.test == 'Completado')
r.confirmScript(job)
assert(launches == 1)
assert(r.run(job))
done(1, '', '')
assert(r.states.test == 'Error')
local result
job.progress = function() end
assert(r.run(job, function(code, stdout, stderr)
  result = { code, stdout, stderr }
end))
streaming({}, 'first ', 'RDS state: ')
streaming({}, '', 'backing-up')
done(1, 'tail', '. Wait.')
assert(result[1] == 1 and result[2] == 'first tail')
assert(result[3] == 'RDS state: backing-up. Wait.', 'streamed stderr and completion tail must survive')
assert(streaming(nil, 'late', 'late') == false)
assert(r.run(job, function(_, _, stderr)
  result = stderr
end))
streaming({}, '', string.rep('x', 9000))
done(1, '', 'end')
assert(#result == 8192 and result:sub(-3) == 'end', 'error buffers must stay bounded')
print('PASS: argument boundaries, duplicate guard, cancellation and completion/error states.')
