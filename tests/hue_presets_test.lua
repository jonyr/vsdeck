--- Cover preset conversion, brightness limits and asynchronous confirmation offline.
-- @script tests.hue_presets_test
package.loaded['modules.config.personal'] = { data = {} }
local presets = require('modules.hue.presets')
local config = { bridge = '192.168.1.2' }
local list = presets.list(config, {})
assert(#list == 6 and list[1].title == 'Trabajo')
local data = {
  state = { on = false, bri = 100, ct = 300, hue = 0, sat = 200, reachable = true, colormode = 'hs', effect = 'none' },
  capabilities = { control = { ct = { min = 200, max = 400 } } },
}
local body = presets.payload(config, { action = 'preset', preset = list[1] }, data)
assert(body.on and body.ct == 200 and body.bri == 254 and body.transitiontime == 4)
body = presets.payload(config, { action = 'preset', preset = list[4] }, data)
assert(body.hue == 50972 and body.sat == 254 and body.bri == 178 and body.effect == 'none')
assert(not presets.payload(config, { action = 'preset', preset = { kelvin = 5000, brightness = 101 } }, data))
assert(not presets.payload(config, { action = 'preset', preset = list[1] }, { state = { bri = 100 } }))
assert(not presets.payload(config, { action = 'preset', preset = list[4] }, { state = { bri = 100, ct = 300 } }))
body = presets.payload(config, { action = 'brightness', step = 10 }, data)
assert(body.bri == 125 and body.on == nil and body.ct == nil and body.hue == nil)
data.state.bri = 250
assert(presets.payload(config, { action = 'brightness', step = 10 }, data).bri == 254)
data.state.bri = 2
assert(presets.payload(config, { action = 'brightness', step = -10 }, data).bri == 1)
data.state = { on = true, reachable = true, bri = 254, ct = 200, colormode = 'ct' }
assert(presets.matches(config, {}, list[1], data))
data.state.bri = 220
assert(not presets.matches(config, {}, list[1], data))
assert(presets.describe(config, {}, data):find('Personalizado'))
-- The state must remain pending until all fields are acknowledged and read back.
local keyCallback, requests, timers, notices = nil, {}, {}, {}
package.loaded['modules.notifications'] = {
  text = function(message)
    notices[#notices + 1] = message
  end,
  info = function() end,
  warning = function() end,
}
hs = {
  task = {
    new = function(_, callback)
      keyCallback = callback
      return {
        start = function()
          return true
        end,
      }
    end,
  },
  timer = {
    doAfter = function(delay, callback)
      local timer = { delay = delay, callback = callback, stop = function() end }
      timers[#timers + 1] = timer
      return timer
    end,
  },
  json = {
    encode = function(value)
      return value
    end,
    decode = function(value)
      return value
    end,
  },
  http = {
    doAsyncRequest = function(_, method, payload, _, callback)
      requests[#requests + 1] = { method = method, payload = payload, callback = callback }
    end,
  },
}
local hue = require('modules.hue')
local command = { lightId = '1', action = 'preset', preset = list[1] }
hue.run(config, command)
keyCallback(0, 'testkey')
requests[1].callback(200, data)
assert(requests[2].method == 'PUT' and requests[2].payload.ct == 200)
local successes = {}
for key, value in pairs(requests[2].payload) do
  successes[#successes + 1] = { success = { ['/lights/1/state/' .. key] = value } }
end
requests[2].callback(200, successes)
assert(hue.state(config, command) == 'loading' and #notices == 0)
assert(timers[2].delay > 0.4)
timers[2].callback()
assert(requests[3].method == 'GET')
data.state.bri = 254
requests[3].callback(200, data)
assert(hue.state(config, command) == 'on' and #notices == 1)
assert(presets.matches(config, {}, list[1], hue.details(config, command)))
local registered = require('modules.hue.actions').build({
  bridge = config.bridge,
  lights = { { id = 'strip', title = 'Strip', lightId = '1' } },
})
assert(registered[2].getPresentation == nil and registered[2].getStatus == nil)
assert(registered[1].getPresentation().label:find('100%%'))
-- A partial acknowledgement must never select the requested preset.
hue.run(config, command)
keyCallback(0, 'testkey')
requests[4].callback(200, data)
requests[5].callback(200, { { success = { ['/lights/1/state/on'] = true } } })
assert(hue.state(config, command) == 'unknown' and hue.details(config, command) == nil)
local light = { id = 'hue.strip', lightId = '1', title = 'Strip' }
local actions = require('modules.hue.actions').build({ bridge = config.bridge, lights = { light } })
assert(#actions == 9 and actions[1].id == 'hue.strip')
assert(actions[2].id == 'hue.strip.preset.work' and actions[8].id == 'hue.strip.brightness.down')
for i = 2, #actions do
  assert(actions[i].getStatus == nil and actions[i].refreshStatus == nil and actions[i].subscribeStatus == nil)
end
light.controls = false
assert(#require('modules.hue.actions').build({ lights = { light } }) == 1)
print('Hue presets, capability guards, brightness limits, observed matching and full confirmation passed')

-- Multiple lights keep separate command targets and visible control labels.
local received = {}
hue.run = function(_, targetCommand)
  received[#received + 1] = targetCommand
end
local multiple = require('modules.hue.actions').build({
  lights = {
    { id = 'one', title = 'Tira', lightId = '6' },
    { id = 'two', title = 'Velador', lightId = '2' },
  },
})
local byId = {}
for _, action in ipairs(multiple) do
  assert(not byId[action.id])
  byId[action.id] = action
end
assert(#multiple == 18 and byId.two.title == 'Velador')
assert(byId['two.preset.red'].title == 'Velador · Rojo')
byId['two.preset.red'].run()
byId['one.preset.green'].run()
assert(received[1].lightId == '2' and received[1].preset.id == 'red')
assert(received[2].lightId == '6' and received[2].preset.id == 'green')
