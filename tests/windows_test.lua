--- Verify source-window geometry without moving any real applications.
-- @script tests.windows_test
package.loaded['modules.config.personal'] = { data = {} }
local notice
package.loaded['modules.notifications'] = {
  warning = function(key)
    notice = key
  end,
  text = function(_, message)
    error(message)
  end,
}
local bounds = { x = 100, y = 30, w = 1200, h = 800 }
local actual = { x = 150, y = 100, w = 600, h = 400 }
local function copy(r)
  return { x = r.x, y = r.y, w = r.w, h = r.h }
end
local screen, other = {}, {
  id = function()
    return 2
  end,
}
function screen:id()
  return 1
end
function screen:frame()
  return copy(bounds)
end
function screen:next()
  return other
end
local selected, fullscreen, standard, refuse = screen, false, true, false
local window = {
  id = function()
    return 10
  end,
  isStandard = function()
    return standard
  end,
  isFullScreen = function()
    return fullscreen
  end,
  screen = function()
    return selected
  end,
  frame = function()
    return copy(actual)
  end,
  setFrame = function(_, goal, duration)
    assert(duration == 0)
    if not refuse then
      actual = copy(goal)
    end
  end,
  moveToScreen = function(_, target, preserveSize, boundsCheck, duration)
    assert(preserveSize == false and boundsCheck == true and duration == 0)
    selected = target
  end,
  focus = function()
    error('Geometry must not focus the window')
  end,
}
hs = {
  window = {
    focusedWindow = function()
      return nil
    end,
  },
  timer = {
    doAfter = function()
      error('No focus timer')
    end,
  },
}
local windows = require('modules.deck.windows')
local action = {
  requiresFocus = false,
  run = function(w)
    windows.run('left', w)
  end,
}
require('modules.deck.executor').new().run(action, window, 'replace')
assert(actual.x == 100 and actual.y == 30 and actual.w == 600 and actual.h == 800)
assert(windows.run('right', window) and actual.x == 700)
assert(windows.run('maximize', window) and actual.w == 1200 and actual.x == 100)
refuse = true
assert(not windows.run('left', window) and notice == 'window.unchanged')
refuse, fullscreen = false, true
assert(not windows.run('left', window) and notice == 'window.fullscreen')
fullscreen, standard = false, false
assert(not windows.run('left', window) and notice == 'window.unsupported')
standard = true
assert(windows.run('next', window) and selected == other)
selected, other = screen, screen
assert(not windows.run('next', window) and notice == 'window.single_screen')
print('Window geometry, focus-independent dispatch, unsupported windows and display guards passed')
