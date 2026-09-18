--- Refresh public action status only while a Deck interface is visible.
-- @module modules.deck.live_status
local M = {}
local t = require('modules.i18n').t

--- Create a visibility-scoped monitor without exposing configuration to the view.
function M.new(actions, render)
  local self = {}
  local timer
  local subscriptions, previous = {}, {}
  local function emit()
    local states = {}
    for _, action in ipairs(actions) do
      if action.getStatus then
        local state = action.getStatus()
        local presentation = action.getPresentation and action.getPresentation() or {}
        local item = {
          id = action.id,
          state = state,
          label = presentation.label or t('deck.light.' .. state),
          active = presentation.active == true,
        }
        local old = previous[action.id]
        if not old or old.state ~= item.state or old.label ~= item.label or old.active ~= item.active then
          states[#states + 1] = item
          previous[action.id] = item
        end
      end
    end
    if #states > 0 then
      render(states)
    end
  end
  local function refresh()
    local seen = {}
    for _, action in ipairs(actions) do
      local key = action.statusKey or action.id
      if action.refreshStatus and not seen[key] then
        seen[key] = true
        action.refreshStatus()
      end
    end
  end
  function self.stop()
    if timer then
      timer:stop()
      timer = nil
    end
    for _, unsubscribe in ipairs(subscriptions) do
      unsubscribe()
    end
    subscriptions, previous = {}, {}
  end
  function self.start()
    self.stop()
    local hasStatus = false
    for _, action in ipairs(actions) do
      if action.getStatus then
        hasStatus = true
        break
      end
    end
    if not hasStatus then
      return
    end
    local seen = {}
    for _, action in ipairs(actions) do
      local source = action.statusSource or action.id
      if action.subscribeStatus and not seen[source] then
        seen[source] = true
        subscriptions[#subscriptions + 1] = action.subscribeStatus(emit)
      end
    end
    emit()
    refresh()
    timer = hs.timer.doEvery(5, refresh)
  end
  return self
end
return M
