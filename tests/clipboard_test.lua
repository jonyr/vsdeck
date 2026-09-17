--- Verify selection capture and delivery without real clipboard or keyboard events.
-- @script tests.clipboard_test

local notifications, queue, keys, content, count, focused, axText, axFails, received
local app = {}
local source = {
  application = function()
    return app
  end,
  id = function()
    return 7
  end,
}
package.loaded['modules.notifications'] = {
  warning = function(key)
    notifications[#notifications + 1] = key
  end,
  success = function(key)
    notifications[#notifications + 1] = key
  end,
}
hs = {
  window = {
    focusedWindow = function()
      return focused
    end,
  },
  pasteboard = {
    getContents = function()
      return content
    end,
    changeCount = function()
      return count
    end,
    setContents = function(value)
      content = value
      count = count + 1
    end,
  },
  axuielement = {
    applicationElement = function(target)
      assert(target == app)
      if axFails then
        error('AX unavailable')
      end
      return {
        attributeValue = function(_, attribute)
          assert(attribute == 'AXFocusedUIElement')
          return {
            attributeValue = function(_, name)
              assert(name == 'AXSelectedText')
              return axText
            end,
          }
        end,
      }
    end,
  },
  eventtap = {
    keyStroke = function(modifiers, key, delay, target)
      assert(modifiers[1] == 'cmd' and delay == 0 and target == app)
      keys[#keys + 1] = key
    end,
  },
  timer = {
    doAfter = function(_, callback)
      queue[#queue + 1] = callback
    end,
  },
}
local clipboard = require('modules.ai_text.clipboard')
local config = { copyDelay = 0.2, copyTimeout = 1.5, pasteDelay = 0.15, restoreClipboardAfterPaste = true }
local function reset()
  notifications, queue, keys, content, count = {}, {}, {}, 'old clipboard', 1
  focused, axText, axFails, received = source, nil, false, nil
end
local function callback(text, previous)
  received = { text, previous }
end
local function tick()
  local fn = table.remove(queue, 1)
  assert(fn)
  fn()
end
local function drain()
  local limit = 100
  while #queue > 0 do
    limit = limit - 1
    assert(limit > 0)
    tick()
  end
end
-- Notes-like controls expose their selection even when Cmd+C never updates anything.
reset()
axText = 'Mañana envío el informe.'
clipboard.copySelection(config, callback, source)
assert(received[1] == axText and received[2] == 'old clipboard')
assert(#keys == 0 and #queue == 0 and count == 1)
-- A delayed copy can arrive after the old 200 ms window; never use old contents.
reset()
axFails = true
clipboard.copySelection(config, callback, source)
assert(keys[1] == 'c')
tick()
tick()
assert(received == nil)
hs.pasteboard.setContents('Fresh selection')
tick()
assert(received[1] == 'Fresh selection' and #queue == 0)
-- Even identical text is accepted when the change counter proves a new copy.
reset()
clipboard.copySelection(config, callback, source)
hs.pasteboard.setContents('old clipboard')
tick()
assert(received[1] == 'old clipboard')
reset()
clipboard.copySelection(config, callback, source)
drain()
assert(received == nil and notifications[1] == 'ai_text.capture_failed' and content == 'old clipboard')
reset()
clipboard.copySelection(config, callback, source)
hs.pasteboard.setContents('')
tick()
assert(received == nil and notifications[1] == 'ai_text.no_selection')
reset()
clipboard.copySelection(config, callback, source)
focused = {}
tick()
assert(received == nil and notifications[1] == 'ai_text.capture_failed')
-- Paste targets the original app and restoration must not erase a later user copy.
reset()
clipboard.pasteResult(config, 'Translated', 'old clipboard', source)
tick()
assert(keys[1] == 'v' and notifications[1] == 'ai_text.replaced')
tick()
assert(content == 'old clipboard')
reset()
clipboard.pasteResult(config, 'Translated', 'old clipboard', source)
tick()
hs.pasteboard.setContents('User copy')
tick()
assert(content == 'User copy')
reset()
clipboard.pasteResult(config, 'Translated', 'old clipboard', source)
focused = {}
tick()
assert(#keys == 0 and content == 'Translated' and notifications[1] == 'ai_text.result_copy_only')
reset()
clipboard.pasteResult(config, 'Translated', 'old clipboard', source)
hs.pasteboard.setContents('Different content')
tick()
assert(#keys == 0 and content == 'Different content' and notifications[1] == 'ai_text.clipboard_changed')
print('PASS: AX selection, delayed/scoped copy, stale clipboard rejection, safe paste and clipboard restoration.')
