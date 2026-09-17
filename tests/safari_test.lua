package.loaded['modules.config.personal']={data={}}
package.path = './?.lua;./?/init.lua;' .. package.path
local queue, events, front, selected, active = {}, {}, true, nil, nil
local old = { id = function() return 1 end, title = function() return 'ARZ — Page' end }
local new = { id = function() return 2 end, title = function() return 'Work — Start Page' end }
local app = {
  isFrontmost = function() return front end,
  allWindows = function() return { old } end,
  focusedWindow = function() return active or old end,
  findMenuItem = function(_, path) return { enabled = path[3] == 'New Work Window' } end,
  selectMenuItem = function(_, path) selected = path[3]; active = new; return true end,
}
local function schedule(repeating, fn)
  local t = { stopped = false, stop = function(self) self.stopped = true end }
  queue[#queue + 1] = { timer = t, fn = fn, repeating = repeating }
  return t
end
hs = {
  application = { launchOrFocusByBundleID = function() return true end, get = function() return app end },
  timer = { doEvery = function(_, fn) return schedule(true, fn) end, doAfter = function(_, fn) return schedule(false, fn) end },
  eventtap = {
    keyStroke = function(_, key) events[#events+1] = key end,
    keyStrokes = function(url) events[#events+1] = url end,
  },
  notify = { new = function() return { send = function() end } end },
}
local function drain()
  local steps = 0
  while #queue > 0 do
    steps = steps + 1; assert(steps < 200, 'sequence did not terminate')
    local item = table.remove(queue, 1)
    if not item.timer.stopped then
      item.fn()
      if item.repeating and not item.timer.stopped then queue[#queue+1] = item end
    end
  end
end
local safari = require('modules.deck.browsers.safari')
assert(not safari.openProfile('', {'https://example.com'}))
assert(not safari.openProfile('Work', {}))
assert(not safari.openProfile('Work', {'javascript:alert(1)'}))
assert(not safari.openProfile('Work', {[1]='https://example.com', [3]='https://example.org'}))
local urls = {'https://example.com', 'https://example.org', 'https://example.net'}
assert(safari.openProfile('Work', urls))
urls[1] = 'https://mutated.example'
assert(not safari.openProfile('Work', urls))
drain()
assert(selected == 'New Work Window')
assert(table.concat(events, '|') == 'l|https://example.com|return|t|l|https://example.org|return|t|l|https://example.net|return')
events = {}; active = nil
assert(safari.openProfile('Work', {'https://example.com'})); drain()
assert(table.concat(events, '|') == 'l|https://example.com|return')
events = {}; active = nil
assert(safari.openProfile('Work', {'https://example.com'})); front = false; drain()
assert(#events == 0)
print('PASS: validation, 1 and 3 URLs in order, copied input, busy guard, timeout without typing.')

local captured
package.loaded['modules.deck.browsers.process']={launch=function(executable,args) captured={executable,args}; return true end}
front=true
assert(safari.open({urls={'https://example.com','https://example.org'}}, {bundle='com.apple.Safari'}))
assert(captured[1]=='/usr/bin/open')
assert(table.concat(captured[2], '|')=='-b|com.apple.Safari|https://example.com|https://example.org')
-- Public entry point delegates to the real Safari adapter.
assert(require('modules.deck.browser').open({browser='safari',profile='Work',urls={'https://example.com'}})); drain()
print('PASS: Safari default adapter and public entry point.')
