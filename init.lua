--- Initialize VSDeck integrations and register application-wide shortcuts.
-- @script init

-- Report configuration failures only after the loader has returned to avoid require cycles.
if require('modules.config.personal').loadError then
  require('modules.notifications').error('config.load_error')
end

--RegisRegister the text and Deck entry points for this Hammerspoon session.--RegisRegister the text and Deck entry points for this Hammerspoon session.--Register the text and Deck entry points for this Hammerspoon session.--Register the text and Deck entry points for this Hammerspoon session.ter the text and Deck entry points for this Hammerspoon session.
local aiText = require('modules.ai_text')

aiText.bindHotkeys({
  hyper = { 'ctrl', 'alt', 'cmd', 'shift' },
  chooserReplace = 'T',
  chooserCopy = 'C',
  translateEnglish = 'E',
  fixSameLanguage = 'F',
})

require('modules.deck').setupMenubar()
require('modules.deck').bindHotkeys({ 'ctrl', 'alt', 'cmd', 'shift' }, 'D')
require('modules.deck.canvas_demo').bindHotkeys({ 'ctrl', 'alt', 'cmd', 'shift' }, 'X')
