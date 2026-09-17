--- Copy selected text and deliver asynchronous text results through the clipboard.
-- @module modules.ai_text.clipboard

local notifications = require('modules.notifications')
local M = {}

--- Copy the selection and wait for the pasteboard to update.
-- @param config Settings containing copyDelay.
-- @param callback Receives selectedText and previousClipboard on nonempty input.
-- A nonempty clipboard does not prove that the source app handled Cmd+C.
function M.copySelection(config, callback)
  local previousClipboard = hs.pasteboard.getContents()

  hs.eventtap.keyStroke({ 'cmd' }, 'c')

  hs.timer.doAfter(config.copyDelay, function()
    local selectedText = hs.pasteboard.getContents()

    if not selectedText or selectedText == '' then
      notifications.warning('ai_text.no_selection')
      return
    end

    callback(selectedText, previousClipboard)
  end)
end

--- Paste into the foreground app and optionally restore its previous clipboard text.
-- @param config Settings containing pasteDelay and restoreClipboardAfterPaste.
-- @param result Rewritten text to paste.
-- @param previousClipboard Previous plain text, or nil.
-- The caller must preserve focus; restoration does not retain images or rich data.
function M.pasteResult(config, result, previousClipboard)
  hs.pasteboard.setContents(result)

  hs.timer.doAfter(config.pasteDelay, function()
    hs.eventtap.keyStroke({ 'cmd' }, 'v')
    notifications.success('ai_text.replaced')

    if config.restoreClipboardAfterPaste and previousClipboard then
      hs.timer.doAfter(0.5, function()
        hs.pasteboard.setContents(previousClipboard)
      end)
    end
  end)
end

return M
