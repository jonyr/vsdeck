--- Exercise the script protocol through the real runner with offline task/UI doubles.
package.path = './?.lua;./?/init.lua;' .. package.path
local calls, shown, notices, timers = {}, {}, {}, {}
local choices, startAllowed = {}, true
local descriptor = {
  version = 1,
  inputs = {
    {
      name = 'app',
      label = 'Application',
      type = 'select',
      options = { { value = 'backend', label = 'Backend' }, { value = 'frontend', label = 'Frontend' } },
    },
  },
}
local decoded = {
  ['describe'] = descriptor,
  ['[]'] = {},
  ['{}'] = {},
  ['backend'] = { app = 'backend' },
  ['frontend'] = { app = 'frontend' },
  ['wrong'] = { app = 'website' },
  ['extra'] = { unknown = 'value' },
  ['progress'] = { type = 'progress', message = 'Publishing' },
  ['result'] = { type = 'result', message = 'Tag sales publicado' },
  ['args'] = { 'space value', '$(never-execute)' },
}
package.loaded['modules.config.personal'] = {
  data = {
    scriptTasks = {
      sales = {
        script = '/scripts/sales.sh',
        env = { EXAMPLE = 'value' },
        resources = { app = { backend = '/backend', frontend = '/frontend' } },
      },
    },
  },
}
package.loaded['modules.tasks.ui'] = {
  register = function(job, target)
    shown[#shown + 1] = job
    job.uid = tostring(#shown)
    job.title = target.title
  end,
  reveal = function() end,
  update = function() end,
  toast = function() end,
  confirm = function(job, callback)
    choices[job.uid] = callback
  end,
}
package.loaded['modules.notifications'] = {
  text = function(...)
    notices[#notices + 1] = { ... }
  end,
}
hs = {
  fs = {
    attributes = function()
      return 'directory'
    end,
    pathToAbsolute = function(path)
      return path
    end,
  },
  json = {
    encode = function(value)
      return table.concat(value, '|')
    end,
    decode = function(value)
      assert(decoded[value], 'invalid JSON')
      return decoded[value]
    end,
  },
  timer = {
    doAfter = function(_, callback)
      local timer = {
        callback = callback,
        stop = function(self)
          self.stopped = true
        end,
      }
      timers[#timers + 1] = timer
      return timer
    end,
  },
  task = {
    new = function(binary, callback, stream, args)
      assert(binary == '/bin/bash')
      if type(stream) == 'table' then
        args, stream = stream, nil
      end
      local task = {
        callback = callback,
        stream = stream,
        args = args,
        start = function()
          return startAllowed
        end,
        environment = function()
          return { INHERITED = 'yes' }
        end,
        setEnvironment = function(self, env)
          self.env = env
          return self
        end,
        setWorkingDirectory = function(self, cwd)
          self.cwd = cwd
          return self
        end,
        terminate = function(self)
          self.terminated = true
        end,
      }
      calls[#calls + 1] = task
      return task
    end,
  },
}
local api = require('modules.tasks.scripts')
local raw = { script = 'sales', mode = 'options' }
assert(api.status(raw).state == 'idle' and #calls == 0)
api.start('one', raw)
assert(calls[1].args[2] == '--describe' and calls[1].cwd == '/scripts')
assert(calls[1].env.INHERITED == 'yes' and calls[1].env.EXAMPLE == 'value')
api.start('duplicate', raw)
assert(#calls == 1)
assert(calls[1].stream == nil, 'option queries must avoid the completion/stream race')
calls[1].callback(0, 'describe', '')
assert(timers[1].stopped and #calls == 1, 'description must not deploy')
choices['1'](true, { app = 'backend' })
assert(calls[2].args[2] == '--run' and calls[2].args[3] == '--app' and calls[2].args[4] == 'backend')
calls[2].stream(nil, 'VSDECK_EV', '')
calls[2].stream(nil, 'ENT progress\n', '')
assert(shown[1].message == 'Publishing')
-- A different button and a direct task share the same repository lock.
local fixed = { script = 'sales', mode = 'options', selection = 'backend' }
api.start('two', fixed)
calls[3].callback(0, 'describe', '')
assert(api.status(fixed).state == 'error' and #calls == 3)
local direct = { script = '/backend/deploy-sales.sh', mode = 'direct' }
api.start('direct-locked', direct)
assert(api.status(direct).state == 'error' and #calls == 3)
calls[2].stream(nil, 'VSDECK_EVENT result\n', 'fatal failure')
assert(api.status(raw).state == 'busy', 'result event cannot complete a running process')
calls[2].callback(1, '', '')
assert(api.status(raw).state == 'error' and shown[1].reason == 'fatal failure')
assert(shown[1].message ~= 'Tag sales publicado', 'nonzero exit overrides claimed success')
assert(calls[2].stream(nil, 'late', '') == false)
api.start('one', raw)
assert(#calls == 3, 'replayed request must not run again')
api.start('three', fixed)
calls[4].callback(0, 'describe', '')
calls[5].stream(nil, string.rep('x', 40000), '')
calls[5].callback(0, 'VSDECK_EVENT result', '')
assert(api.status(fixed).state == 'done' and shown[#shown].message == 'Tag sales publicado')
assert(#shown[#shown].logs <= 32768)
api.start('cancel', raw)
calls[6].callback(0, 'describe', '')
choices[shown[#shown].uid](false)
assert(api.status(raw).state == 'cancelled' and #calls == 6)
local wrong = { script = 'sales', selection = 'wrong' }
api.start('wrong', wrong)
calls[7].callback(0, 'describe', '')
assert(api.status(wrong).state == 'error' and #calls == 7)
api.start('malformed', raw)
calls[8].callback(0, 'broken', '')
assert(api.status(raw).state == 'error')
api.start('timeout', raw)
timers[#timers].callback()
assert(calls[9].terminated)
calls[9].callback(15, '', '')
assert(api.status(raw).state == 'error')
api.start('oversize', raw)
calls[10].callback(0, string.rep('x', 70000), '')
assert(api.status(raw).state == 'error')
startAllowed = false
api.start('failed-start', direct)
assert(api.status(direct).state == 'error')
startAllowed = true
direct.args = 'args'
api.start('direct', direct)
assert(calls[#calls].args[2] == 'space value' and calls[#calls].args[3] == '$(never-execute)')
calls[#calls].callback(0, 'finished', '')
assert(api.status(direct).state == 'done')
print(
  'PASS: script selection, arguments, streamed events/tails, exit status, replay, resource locks, bounded logs, timeout and launch failure.'
)
