--- Read selected text and deliver results to the original application.
-- @module modules.ai_text.clipboard

local notifications = require('modules.notifications')
local M = {}

-- AXSelectedText reads the editor selection without depending on Cmd+C timing.
-- Unsupported or inaccessible controls fall back to a verified clipboard copy.
local function accessibleSelection(app)
  local ok, text = pcall(function()
    local application = hs.axuielement.applicationElement(app)
    local element = application and application:attributeValue('AXFocusedUIElement')
    return element and element:attributeValue('AXSelectedText')
  end)
  if ok and type(text) == 'string' and text ~= '' then
    return text
  end
end

--- Read the source selection, using targeted Cmd+C only when AX is unavailable.
-- @param config Settings containing copyDelay and optional copyTimeout.
-- @param callback Receives selectedText and previousClipboard on success.
-- @param sourceWindow Original application window; defaults to the focused window.
-- A clipboard value is accepted only after its change count advances.
function M.copySelection(config, callback, sourceWindow)
  local previousClipboard = hs.pasteboard.getContents()
  sourceWindow = sourceWindow or hs.window.focusedWindow()
  local app = sourceWindow and sourceWindow:application()
  if not app or hs.window.focusedWindow() ~= sourceWindow then
    notifications.warning('ai_text.capture_failed')
    return
  end

  local selected = accessibleSelection(app)
  if selected then
    callback(selected, previousClipboard)
    return
  end

  local count = hs.pasteboard.changeCount()
  hs.eventtap.keyStroke({ 'cmd' }, 'c', 0, app)
  local timeout = tonumber(config.copyTimeout) or 1.5
  local delay = math.max(0.05, math.min(tonumber(config.copyDelay) or 0.2, timeout))
  local remaining = math.max(1, math.ceil((timeout - delay) / 0.05))
  local function poll()
    if hs.window.focusedWindow() ~= sourceWindow then
      notifications.warning('ai_text.capture_failed')
      return
    end
    if hs.pasteboard.changeCount() ~= count then
      local text = hs.pasteboard.getContents()
      if type(text) == 'string' and text ~= '' then
        callback(text, previousClipboard)
      else
        notifications.warning('ai_text.no_selection')
      end
      return
    end
    remaining = remaining - 1
    if remaining <= 0 then
      notifications.warning('ai_text.capture_failed')
      return
    end
    hs.timer.doAfter(0.05, poll)
  end
  hs.timer.doAfter(delay, poll)
end

--- Paste only while the original window still owns the focus.
-- @param config Settings containing pasteDelay and restoreClipboardAfterPaste.
-- @param result Rewritten text to paste.
-- @param previousClipboard Previous plain text, or nil.
-- @param sourceWindow Original application window captured before the request.
-- If focus changed while waiting for the model, leave the result copied instead.
function M.pasteResult(config, result, previousClipboard, sourceWindow)
  hs.pasteboard.setContents(result)
  local resultCount = hs.pasteboard.changeCount()
  hs.timer.doAfter(config.pasteDelay, function()
    if not sourceWindow or not sourceWindow:id() or hs.window.focusedWindow() ~= sourceWindow then
      notifications.warning('ai_text.result_copy_only')
      return
    end
    if hs.pasteboard.changeCount() ~= resultCount then
      notifications.warning('ai_text.clipboard_changed')
      return
    end
    hs.eventtap.keyStroke({ 'cmd' }, 'v', 0, sourceWindow:application())
    notifications.success('ai_text.replaced')

    if config.restoreClipboardAfterPaste and previousClipboard then
      hs.timer.doAfter(0.5, function()
        -- Do not overwrite anything the user copied while the result was pasted.
        if hs.pasteboard.changeCount() == resultCount then
          hs.pasteboard.setContents(previousClipboard)
        end
      end)
    end
  end)
end

return M
