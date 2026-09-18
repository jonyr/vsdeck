--- Verify silent reads, confirmed state and stale-response guards without a real Bridge.
-- @script tests.hue_status_test
package.loaded['modules.config.personal'] = { data = {} }
local notices, tasks, requests, timers = {}, {}, {}, {}
package.loaded['modules.notifications'] = {
  text = function(...)
    notices[#notices + 1] = { ... }
  end,
  warning = function(...)
    notices[#notices + 1] = { ... }
  end,
  info = function(...)
    notices[#notices + 1] = { ... }
  end,
}
hs = {
  timer = {
    doAfter = function(_, callback)
      local timer = { callback = callback, stop = function() end }
      timers[#timers + 1] = timer
      return timer
    end,
  },
  task = {
    new = function(_, callback)
      tasks[#tasks + 1] = callback
      return {
        start = function()
          return true
        end,
      }
    end,
  },
  http = {
    doAsyncRequest = function(_, method, _, _, callback)
      requests[#requests + 1] = { method = method, callback = callback }
    end,
  },
  json = {
    decode = function(value)
      return value
    end,
    encode = function(value)
      return value
    end,
  },
}
local hue = require('modules.hue')
local config, light = { bridge = '192.168.1.2' }, { lightId = '1' }
local changes = 0
local unsubscribe = hue.subscribe(function()
  changes = changes + 1
end)
assert(hue.state(config, light) == 'unknown')
hue.refresh(config, light)
hue.refresh(config, light)
assert(#tasks == 1 and hue.state(config, light) == 'loading')
tasks[1](0, 'testkey')
assert(requests[1].method == 'GET')
requests[1].callback(200, { state = { on = true, reachable = true } })
assert(hue.state(config, light) == 'on' and #notices == 0 and #requests == 1)
hue.refresh(config, light)
tasks[2](0, 'testkey')
local stale = requests[2].callback
hue.run(config, light)
tasks[3](0, 'testkey')
requests[3].callback(200, { state = { on = true, reachable = true } })
assert(requests[4].method == 'PUT' and hue.state(config, light) == 'loading')
requests[4].callback(200, { { success = { ['/lights/1/state/on'] = false } } })
assert(hue.state(config, light) == 'off')
stale(200, { state = { on = true } })
assert(hue.state(config, light) == 'off')
local noticeCount = #notices
hue.refresh(config, light)
tasks[4](0, 'testkey')
requests[5].callback(200, { state = { on = false, reachable = false } })
assert(hue.state(config, light) == 'unreachable' and #notices == noticeCount)
hue.refresh(config, light)
tasks[5](0, 'testkey')
timers[#timers].callback()
assert(hue.state(config, light) == 'unknown')
requests[6].callback(200, { state = { on = true } })
assert(hue.state(config, light) == 'unknown')
unsubscribe()
local oldChanges = changes
hue.refresh(config, light)
tasks[6](1, '')
assert(changes == oldChanges and #notices == noticeCount)
-- Monitor polling and subscriptions must be released when a panel hides.
local tick, stopped, renders = nil, 0, 0
hs.timer.doEvery = function(interval, callback)
  assert(interval == 5)
  tick = callback
  return {
    stop = function()
      stopped = stopped + 1
    end,
  }
end
local action = {
  id = 'hue.test',
  subscribeStatus = require('modules.hue').subscribe,
  getStatus = function()
    return hue.state(config, light)
  end,
  refreshStatus = function()
    hue.refresh(config, light)
  end,
}
local monitor = require('modules.deck.live_status').new({ action }, function(states)
  assert(states[1].id == action.id and states[1].label ~= nil)
  assert(states[1].bridge == nil and states[1].key == nil)
  renders = renders + 1
end)
monitor.start()
tasks[#tasks](0, 'testkey')
requests[#requests].callback(200, { state = { on = true } })
assert(renders >= 2)
tick()
monitor.stop()
local before = renders
tasks[#tasks](0, 'testkey')
requests[#requests].callback(200, { state = { on = false } })
assert(renders == before and stopped == 1)
print('Hue status reads, confirmed changes, timeout, stale callbacks and monitor cleanup passed')
