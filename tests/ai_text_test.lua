--- Preserve the captured window from Stream Deck dispatch through asynchronous delivery.
-- @script tests.ai_text_test

package.loaded['modules.config.personal'] = { data = {} }
package.loaded['config'] = {}
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
local ai = require('modules.ai_text')
local action = require('modules.ai_text.actions').byId.translate_en
ai.runAction(action, 'replace', source)
assert(completion and not pasted)
completion('Selected text')
assert(pasted)
pasted, completion = nil, nil
ai.runAction(action, 'copy', source)
completion('Selected text')
assert(not pasted and copied == 'Selected text' and notices == 'ai_text.copied')
print('PASS: Source window survives model request and copy/replace delivery.')
