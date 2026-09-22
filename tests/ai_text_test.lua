local function actionById(id)
  for _, action in ipairs(require('modules.ai_text.actions').list) do
    if action.id == id then
      return action
    end
  end
  error('Unknown action: ' .. id)
end
--- Preserve the captured window from Stream Deck dispatch through asynchronous delivery.
-- @script tests.ai_text_test

package.loaded['modules.config.personal'] = { data = {} }
package.loaded['config'] = {}
local source, other = {}, {}
local completion, pasted
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
hs = {
  window = {
    focusedWindow = function()
      return other
    end,
  },
}
local ai = require('modules.ai_text')
local action = actionById('translate_en')
ai.runAction(action, source)
assert(completion and not pasted)
completion('Selected text')
assert(pasted)
print('PASS: Source window survives model request and replacement delivery.')
