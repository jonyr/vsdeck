local notifications = require('modules.notifications')
local config = require('config')
local actions = require('modules.ai_text.actions')
local chooser = require('modules.ai_text.chooser')
local clipboard = require('modules.ai_text.clipboard')
local lmStudio = require('modules.ai_text.lm_studio')

local M = {}

function M.runAction(action, mode)
  clipboard.copySelection(config, function(selectedText, previousClipboard)
    lmStudio.call(config, action, selectedText, function(result)
      if mode == 'copy' then
        hs.pasteboard.setContents(result)
        notifications.success('ai_text.copied')
        return
      end

      clipboard.pasteResult(config, result, previousClipboard)
    end)
  end)
end

function M.chooseAction(mode)
  chooser.show(actions, mode, M.runAction)
end

function M.bindHotkeys(keys)
  local hyper = keys.hyper or { 'ctrl', 'alt', 'cmd' }

  hs.hotkey.bind(hyper, keys.chooserReplace or 'T', function()
    M.chooseAction('replace')
  end)

  hs.hotkey.bind(hyper, keys.chooserCopy or 'C', function()
    M.chooseAction('copy')
  end)

  hs.hotkey.bind(hyper, keys.translateEnglish or 'E', function()
    M.runAction(actions.list[1], 'replace')
  end)

  hs.hotkey.bind(hyper, keys.fixSameLanguage or 'F', function()
    M.runAction(actions.list[2], 'replace')
  end)
end

return M
