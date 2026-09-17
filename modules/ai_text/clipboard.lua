local notifications = require('modules.notifications')
local M = {}

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
