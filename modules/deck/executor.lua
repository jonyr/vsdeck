--- Guard action dispatch and source-window focus for both Deck interfaces.
-- @module modules.deck.executor

local t = require('modules.i18n').t
-- Shared dispatch rules for the HTML and Canvas interfaces.
local M = {}
--- Create an independent dispatcher with at most one pending focus timer.
-- @return Object exposing isBusy, cancel and run; cancel only cancels dispatch.
function M.new()
  local timer
  local self = {}
  local function notify(message)
    require('modules.notifications').text('error', message)
  end
  -- Busy refers only to the pending focus timer, not an asynchronous action already launched.
  function self.isBusy()
    return timer ~= nil
  end
  function self.cancel()
    if timer then
      timer:stop()
      timer = nil
    end
  end
  function self.run(action, target, mode)
    if timer or not action or (mode ~= 'copy' and mode ~= 'replace') then
      return
    end
    -- Actions without a source window bypass focus restoration but still report failures.
    if action.requiresOrigin == false then
      if not pcall(action.run) then
        notify(t('deck.run_error'))
      end
      return
    end
    if not target or not target:id() then
      notify(t('deck.no_origin'))
      return
    end
    target:focus()
    -- Let macOS complete the focus change and verify it before running the action.
    timer = hs.timer.doAfter(0.2, function()
      timer = nil
      if hs.window.focusedWindow() ~= target then
        notify(t('deck.focus_error'))
        return
      end
      if not pcall(action.run, target, mode) then
        notify(t('deck.run_error'))
      end
    end)
  end
  return self
end
return M
