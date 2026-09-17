--- Preserve the captured window from Deck dispatch through asynchronous delivery.
-- @script tests.ai_text_test

package.loaded['modules.config.personal'] = { data = {} }
package.loaded['config'] = {}
package.loaded['modules.ai_text.chooser'] = {}
local source, other = {}, {}
local completion, copied, pasted, notices
package.loaded['modules.ai_text.clipboard'] = {
  copySelection = function(_, callback, window)
    assert(window == source)
    callback('Texto seleccionado', 'previous')
  end,
  pasteResult = function(_, text, previous, window)
    assert(text == 'Selected text' and previous == 'previous' and window == source)
    pasted = true
  end,
}
package.loaded['modules.ai_text.lm_studio'] = {
  call = function(_, action, text, callback)
    assert(action.id == 'translate_en' and text == 'Texto seleccionado')
    completion = callback
  end,
}
package.loaded['modules.notifications'] = {
  success = function(key)
    notices = key
  end,
}
hs = {
  window = {
    focusedWindow = function()
      return other
    end,
  },
  pasteboard = {
    setContents = function(text)
      copied = text
    end,
  },
}
local catalog = require('modules.deck.actions')
catalog.byId['text.translate_en'].run(source, 'replace')
assert(completion and not pasted)
completion('Selected text')
assert(pasted)
pasted, completion = nil, nil
catalog.byId['text.translate_en'].run(source, 'copy')
completion('Selected text')
assert(not pasted and copied == 'Selected text' and notices == 'ai_text.copied')
print('PASS: Deck source survives model request and copy/replace delivery.')
