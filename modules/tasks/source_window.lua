--- Resolve the source application before a task window takes keyboard focus.
-- @module modules.tasks.source_window

local M = {}

local function isSource(window)
  if not window or not window:id() then
    return false
  end
  local app = window:application()
  return app ~= nil and app:bundleID() ~= 'org.hammerspoon.Hammerspoon' and app:bundleID() ~= 'com.elgato.StreamDeck'
end

--- Capture the focused app window, falling back to front-to-back visible windows.
-- A menu-bar click can temporarily clear focus. Never select a task window or console
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

--- Restore the previous editor only when Stream Deck itself owns keyboard focus.
-- Physical keys keep the current editor unchanged. Never copy from the launcher.
-- @param callback Receives the focused source window, or nil if restoration failed.
function M.forText(callback)
  local focused = hs.window.focusedWindow()
  local app = focused and focused:application()
  if not app or not app.bundleID or app:bundleID() ~= 'com.elgato.StreamDeck' then
    callback(focused)
    return
  end
  local source = M.capture()
  if not source then
    callback(nil)
    return
  end
  local ok = pcall(function()
    source:focus()
  end)
  if not ok then
    callback(nil)
    return
  end
  local attempts = 0
  local function check()
    local current = hs.window.focusedWindow()
    if current == source then
      callback(source)
      return
    end
    attempts = attempts + 1
    -- A user switching to a third window cancels restoration rather than stealing focus again.
    if (current and current ~= focused) or attempts >= 5 then
      callback(nil)
      return
    end
    hs.timer.doAfter(0.05, check)
  end
  hs.timer.doAfter(0.05, check)
end

return M
