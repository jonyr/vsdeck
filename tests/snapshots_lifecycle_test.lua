--- Exercise RDS lifecycle without AWS, dialogs, personal settings or real processes.
package.path = './?.lua;./?/init.lua;' .. package.path
package.loaded['modules.config.personal'] = { data = {} }
local calls, notices, pending = {}, {}, nil
local confirm
local presented = {}
package.loaded['modules.tasks.ui'] = {
  register = function(job, _, origin)
    job.origin = origin
  end,
  update = function(job)
    presented[#presented + 1] = job.phase
  end,
  confirm = function(_, callback)
    confirm = callback
  end,
  toast = function() end,
}
package.loaded['modules.notifications'] = {
  text = function(level, message, options)
    notices[#notices + 1] = { options.title, message, options.final, level }
    options.present()
  end,
}
package.loaded['modules.i18n'] = {
  t = function(key)
    return key
  end,
}
package.loaded['modules.tasks.notifications'] = {
  send = function(...)
    notices[#notices + 1] = { ... }
  end,
}
local runner = {
  run = function(job, callback)
    calls[#calls + 1] = { job = job, callback = callback }
    return true
  end,
}
package.loaded['modules.tasks.runner'] = runner
hs = {
  configdir = '/mock',
  timer = {
    doAfter = function(_, fn)
      pending = fn
      return {}
    end,
  },
}
local snapshots = require('modules.tasks.snapshots')
local target = { id = 'physical', title = 'Backup', profile = 'work', region = 'us-east-1', instance = 'hotel-db' }
assert(snapshots.status(target).state == 'idle')
assert(snapshots.start('request-1', target).phase == 'queued')
assert(#calls == 0, 'IPC start must return before a dialog can be opened')
snapshots.start('duplicate-request', target)
assert(#calls == 0, 'physical buttons must share the pending lock')
pending()
assert(#calls == 1 and calls[1].job.args[1] == 'inspect')
calls[1].callback(0, '123456789012\n', '')
assert(#calls == 1 and snapshots.status(target).phase == 'confirm', 'creating must wait for explicit UI confirmation')
confirm(true)
confirm(true) -- stale duplicate cannot execute twice
assert(#calls == 2 and calls[2].job.args[1] == 'create')
assert(calls[2].job.args[7] == '123456789012')
assert(calls[2].job.args[6]:match('^hotel%-db%-%d+%-%d+%-manual$'))
snapshots.start('request-2', target)
assert(#calls == 2)
calls[2].job.progress('Solicitado: hotel-db')
assert(snapshots.status(target).phase == 'waiting')
calls[2].callback(0, '', '')
assert(snapshots.status(target).state == 'done' and notices[#notices][4] == 'success')
snapshots.start('request-1', target)
assert(#calls == 2, 'same request cannot execute again after success')
snapshots.start('request-3', target)
pending()
calls[3].callback(0, '123456789012', '')
confirm(false)
assert(#calls == 3 and snapshots.status(target).state == 'cancelled')
snapshots.start('request-4', target)
pending()
calls[4].callback(1, '', 'SSO expired')
assert(snapshots.status(target).state == 'error')
assert(snapshots.status(target).reason == 'SSO expired')
assert(not pcall(snapshots.start, 'invalid', { profile = '$(shell)', region = 'us-east-1', instance = 'hotel-db' }))
package.loaded['modules.tasks.ui'].confirm = function()
  error('UI unavailable')
end
snapshots.start('request-5', target)
pending()
calls[5].callback(0, '123456789012', '')
assert(#calls == 5 and snapshots.status(target).state == 'error', 'broken confirmation must fail closed')
runner.run = function()
  return false
end
snapshots.start('request-6', target)
pending()
assert(snapshots.status(target).state == 'error', 'failed spawn releases the lock')
print('Snapshot lifecycle tests passed')
