local settings = {
  lmStudioUrl = 'http://localhost:1234/v1/chat/completions',
  copyDelay = 0.20, pasteDelay = 0.15, restoreClipboardAfterPaste = true,
}
local ai = require('modules.config.personal').data.ai or {}
for key, value in pairs(ai) do settings[key] = value end
return settings
