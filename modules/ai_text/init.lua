--- Coordinate text capture, model requests and replacement delivery.
-- @module modules.ai_text.init

local config = require('config')
local clipboard = require('modules.ai_text.clipboard')
local lmStudio = require('modules.ai_text.lm_studio')

local M = {}

--- Run a transformation asynchronously against the current selection.
-- @param action Action metadata including the model instruction.
-- @param sourceWindow Optional original window supplied by the Deck dispatcher.
-- @param operation Optional active/finish lifecycle owned by the caller.
function M.runAction(action, sourceWindow, operation)
  sourceWindow = sourceWindow or hs.window.focusedWindow()
  clipboard.copySelection(config, function(selectedText, previousClipboard)
    lmStudio.call(config, action, selectedText, function(result)
      clipboard.pasteResult(config, result, previousClipboard, sourceWindow, operation)
    end, operation)
  end, sourceWindow, operation)
end

return M
