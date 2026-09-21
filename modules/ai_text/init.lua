--- Coordinate text capture, model requests and copy/replace delivery.
-- @module modules.ai_text.init

local notifications = require('modules.notifications')
local config = require('config')
local clipboard = require('modules.ai_text.clipboard')
local lmStudio = require('modules.ai_text.lm_studio')

local M = {}

--- Run a transformation asynchronously against the current selection.
-- @param action Action metadata including the model instruction.
-- @param mode "copy" keeps the result on the clipboard; otherwise it is pasted.
-- @param sourceWindow Optional original window supplied by the Deck dispatcher.
-- @param operation Optional active/finish lifecycle owned by the caller.
function M.runAction(action, mode, sourceWindow, operation)
  local notifier = operation and operation.notifications or notifications
  sourceWindow = sourceWindow or hs.window.focusedWindow()
  clipboard.copySelection(config, function(selectedText, previousClipboard)
    lmStudio.call(config, action, selectedText, function(result)
      if mode == 'copy' then
        hs.pasteboard.setContents(result)
        notifier.success('ai_text.copied')
        if operation then
          operation.finish('done')
        end
        return
      end

      clipboard.pasteResult(config, result, previousClipboard, sourceWindow, operation)
    end, operation)
  end, sourceWindow, operation)
end

return M
