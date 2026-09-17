local aiText = require('modules.ai_text')

aiText.bindHotkeys({
  hyper = { 'ctrl', 'alt', 'cmd', 'shift' },
  chooserReplace = 'T',
  chooserCopy = 'C',
  translateEnglish = 'E',
  fixSameLanguage = 'F'
})

require('modules.deck').setupMenubar()
require('modules.deck').bindHotkeys({ 'ctrl', 'alt', 'cmd', 'shift' }, 'D')
require('modules.deck.canvas_demo').bindHotkeys({ 'ctrl', 'alt', 'cmd', 'shift' }, 'X')
