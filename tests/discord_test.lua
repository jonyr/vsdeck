--- Verify voice toggles without touching a live Discord call.
-- @script tests.discord_test
package.loaded['modules.config.personal'] = { data = {} }
local notices, sent, timers = {}, {}, {}
package.loaded['modules.notifications'] = {
  warning = function(key)
    notices[#notices + 1] = key
  end,
  error = function(key)
    notices[#notices + 1] = key
  end,
}
local permission, running, activate, secure, failSend = true, true, true, false, false
local app = {
  pid = function()
    return 12
  end,
  isRunning = function()
    return running
  end,
  activate = function()
    return activate
  end,
}
local front = app
hs = {
  accessibilityState = function()
    return permission
  end,
  application = {
    applicationsForBundleID = function(id)
      assert(id == 'com.hnc.Discord')
      return running and { app } or {}
    end,
    frontmostApplication = function()
      return front
    end,
  },
  eventtap = {
    isSecureInputEnabled = function()
      return secure
    end,
    keyStroke = function(modifiers, key, delay, target)
      assert(target == app and delay == 0)
      assert(modifiers[1] == 'cmd' and modifiers[2] == 'shift')
      if failSend then
        error('simulated delivery failure')
      end
      sent[#sent + 1] = key
    end,
  },
  timer = {
    doAfter = function(delay, callback)
      local timer = { delay = delay, callback = callback }
      function timer:stop()
        self.stopped = true
      end
      timers[#timers + 1] = timer
      return timer
    end,
  },
}
local refreshes = 0
package.loaded['modules.discord.status'] = {
  refresh = function()
    refreshes = refreshes + 1
  end,
  stop = function() end,
  state = function()
    return 'unknown'
  end,
}
local discord = require('modules.discord')
assert(not discord.run('unknown') and #timers == 0)
permission = false
assert(not discord.run('mute') and notices[#notices] == 'discord.accessibility')
permission, running = true, false
assert(not discord.run('mute') and notices[#notices] == 'discord.not_running')
running, activate = true, false
assert(not discord.run('mute') and notices[#notices] == 'discord.focus_error')
activate = true
assert(discord.run('mute'))
assert(not discord.run('deafen'))
front = {
  pid = function()
    return 99
  end,
}
timers[#timers].callback()
assert(#sent == 0 and notices[#notices] == 'discord.focus_error')
front, secure = app, true
assert(discord.run('mute'))
timers[#timers].callback()
assert(#sent == 0 and notices[#notices] == 'discord.secure_input')
secure = false
assert(discord.run('mute'))
timers[#timers].callback()
assert(sent[1] == 'm' and not discord.run('deafen'))
timers[#timers].callback()
assert(discord.run('deafen'))
timers[#timers].callback()
assert(sent[2] == 'd')
timers[#timers].callback()
assert(refreshes == 2)
failSend = true
assert(discord.run('mute'))
timers[#timers].callback()
assert(notices[#notices] == 'discord.send_error' and #sent == 2)
failSend = false
assert(discord.run('mute'))
discord.stop()
assert(timers[#timers].stopped)
local actions = discord.actions()
assert(#actions == 2 and actions[1].id == 'discord.mute' and actions[2].id == 'discord.deafen')
for _, action in ipairs(actions) do
  assert(action.requiresOrigin == false and action.category == 'Discord')
end
require('modules.deck.executor').new().run(actions[1], nil, 'replace')
timers[#timers].callback()
assert(sent[3] == 'm')
discord.stop()
print('Discord targeting, permission/focus guards, debounce, errors and shared dispatch passed')
