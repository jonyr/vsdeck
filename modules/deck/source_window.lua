--- Resolve the source application before a Deck takes keyboard focus.
-- @module modules.deck.source_window

local M = {}

local function isSource(window)
  if not window or not window:id() then
    return false
  end
  local app = window:application()
  return app ~= nil and app:bundleID() ~= 'org.hammerspoon.Hammerspoon'
end

--- Capture the focused app window, falling back to front-to-back visible windows.
-- A menu-bar click can temporarily clear focus. Never select a Deck or console
-- owned by Hammerspoon, and never reuse a previously closed source window.
-- @return Source window, or nil when no external application window is available.
function M.capture()
  local focused = hs.window.focusedWindow()
  if isSource(focused) then
    return focused
  end
  for _, window in ipairs(hs.window.orderedWindows()) do
    if isSource(window) then
      return window
    end
  end
  return nil
end

return M
