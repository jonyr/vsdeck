--- Arrange the captured source window directly, independently of Deck keyboard focus.
-- @module modules.deck.windows
local M = {}
local function same(a, b)
  return math.abs(a.x - b.x) < 2 and math.abs(a.y - b.y) < 2 and math.abs(a.w - b.w) < 2 and math.abs(a.h - b.h) < 2
end

--- Apply geometry without typing or moving a full-screen window out of its Space.
function M.run(operation, window)
  local notify = require('modules.notifications')
  if not window:isStandard() then
    notify.warning('window.unsupported')
    return false
  end
  if window:isFullScreen() then
    notify.warning('window.fullscreen')
    return false
  end
  local screen, before = window:screen(), window:frame()
  if not screen then
    notify.warning('window.unsupported')
    return false
  end
  if operation == 'next' then
    local nextScreen = screen:next()
    if not nextScreen or nextScreen:id() == screen:id() then
      notify.warning('window.single_screen')
      return false
    end
    window:moveToScreen(nextScreen, false, true, 0)
    if window:screen():id() ~= nextScreen:id() then
      notify.warning('window.unchanged')
      return false
    end
    return true
  end
  local goal = screen:frame()
  if operation == 'left' or operation == 'right' then
    goal.w = goal.w / 2
    if operation == 'right' then
      goal.x = goal.x + goal.w
    end
  elseif operation ~= 'maximize' then
    return false
  end
  window:setFrame(goal, 0)
  if not same(before, goal) and same(before, window:frame()) then
    notify.warning('window.unchanged')
    return false
  end
  return true
end
return M
