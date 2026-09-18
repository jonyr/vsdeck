--- Verify observed Discord states without changing a real microphone or call.
-- @script tests.discord_status_test
local timers, permission, running, clock = {}, true, true, 0
local function element(attributes)
  return {
    attributeValue = function(_, key)
      return attributes[key]
    end,
    setTimeout = function(_, value)
      assert(value == 0.05)
    end,
  }
end
local mic = { AXRole = 'AXCheckBox', AXDescription = 'Mute', AXValue = '', AXEnabled = true }
local audio = { AXRole = 'AXCheckBox', AXDescription = 'Deafen', AXValue = '', AXEnabled = true }
local root = element({ AXChildren = { element(mic), element(audio) } })
local app = {
  pid = function()
    return 12
  end,
  isRunning = function()
    return running
  end,
}
hs = {
  accessibilityState = function()
    return permission
  end,
  application = {
    applicationsForBundleID = function()
      return running and { app } or {}
    end,
  },
  axuielement = {
    applicationElement = function()
      return root
    end,
  },
  timer = {
    secondsSinceEpoch = function()
      return clock
    end,
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
}
local status = require('modules.discord.status')
local renders = 0
local unsubscribe = status.subscribe(function()
  renders = renders + 1
end)
local function drain()
  while #timers > 0 do
    local timer = table.remove(timers, 1)
    if not timer.stopped then
      timer.callback()
    end
  end
end
status.refresh()
drain()
-- Observed Discord fixture: names stay fixed, switch values are empty, and
-- the icons have no accessible state. Nearby text must not override that absence.
assert(status.state('mute') == 'unknown' and status.state('deafen') == 'unknown')
mic.AXChildren = { element({ AXRole = 'AXImage' }) }
mic.AXSelected, audio.AXSelected = true, true
mic.AXHelp, audio.AXHelp = 'Unmute', 'Undeafen'
status.refresh()
assert(status.state('mute') == 'unknown' and status.state('deafen') == 'unknown')
-- Changing an identifier alone still cannot establish state.
mic.AXDescription, audio.AXDescription = 'Unmute', 'Undeafen'
status.refresh()
assert(status.state('mute') == 'unknown' and status.state('deafen') == 'unknown')
for _, value in ipairs({ '', 'mixed', 'true', 'false', 2, {} }) do
  mic.AXValue = value
  status.refresh()
  assert(status.state('mute') == 'unknown')
end
mic.AXValue = nil
status.refresh()
assert(status.state('mute') == 'unknown')
-- Synthetic AX contract checks, NOT evidence of live Discord transitions.
-- Explicit boolean/0/1 values are decoded independently of the fixed label.
mic.AXDescription, audio.AXDescription = 'Mute', 'Deafen'
for _, pair in ipairs({ { true, false }, { 1, 0 }, { '1', '0' } }) do
  mic.AXValue, audio.AXValue = pair[1], pair[1]
  status.refresh()
  assert(status.state('mute') == 'muted' and status.state('deafen') == 'deafened')
  mic.AXValue, audio.AXValue = pair[2], pair[2]
  status.refresh()
  assert(status.state('mute') == 'unmuted' and status.state('deafen') == 'listening')
end
mic.AXValue, audio.AXValue = '', ''
status.refresh()
assert(status.state('mute') == 'unknown' and status.state('deafen') == 'unknown')
audio.AXValue, audio.AXEnabled = true, false
status.refresh()
assert(status.state('deafen') == 'unknown')
-- Unknown language or a stale object must not retain the last confirmed state.
mic.AXDescription = nil
status.refresh()
drain()
assert(status.state('mute') == 'unknown')
permission = false
status.refresh()
assert(status.state('mute') == 'permission')
permission, running = true, false
status.refresh()
assert(status.state('deafen') == 'closed')
running = true
status.refresh()
local before = renders
unsubscribe()
drain()
assert(renders == before and status.state('mute') == 'unknown')
-- A bounded scan expires and publishes unknown instead of retaining old state.
mic.AXDescription, audio.AXEnabled = 'Mute', true
status.refresh()
clock = 4
drain()
assert(status.state('mute') == 'unknown')
status.refresh()
drain()
assert(status.state('mute') == 'unknown')
status.stop()
print('Discord fixed-label regression, explicit AX contract, unknown values, permissions and cancellation passed')
