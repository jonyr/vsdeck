--- Reproduce transient menu-bar focus loss without interacting with real apps.
-- @script tests.source_window_test

local focused, ordered
local function window(id, bundle)
  return {
    id = function()
      return id
    end,
    application = function()
      if not bundle then
        return nil
      end
      return {
        bundleID = function()
          return bundle
        end,
      }
    end,
  }
end
hs = {
  window = {
    focusedWindow = function()
      return focused
    end,
    orderedWindows = function()
      return ordered
    end,
  },
}
local source = require('modules.tasks.source_window')
local editor = window(1, 'test.editor')
local browser = window(2, 'test.browser')
local deck = window(3, 'org.hammerspoon.Hammerspoon')
focused, ordered = editor, { browser, editor }
assert(source.capture() == editor)
-- A menu-bar click removes focus but leaves the editor frontmost below the Deck.
focused, ordered = nil, { deck, editor, browser }
assert(source.capture() == editor)
focused = deck
assert(source.capture() == editor)
-- Closed windows and missing app handles must not become paste targets.
focused, ordered = window(nil, 'test.editor'), { window(4, nil), browser }
assert(source.capture() == browser)
focused, ordered = nil, { deck }
assert(source.capture() == nil)
ordered = {}
assert(source.capture() == nil)
print('PASS: focused source, menu-bar focus loss, Deck exclusion and missing/closed windows.')

-- Virtual Stream Deck steals focus before dispatch; restore only its previous editor.
local queue, focusCalls = {}, 0
hs.timer = {
  doAfter = function(_, callback)
    queue[#queue + 1] = callback
  end,
}
local virtual = window(5, 'com.elgato.StreamDeck')
editor.focus = function()
  focusCalls = focusCalls + 1
  focused = editor
end
focused, ordered = virtual, { virtual, deck, editor, browser }
local received
source.forText(function(value)
  received = value
end)
assert(focusCalls == 1 and received == nil)
table.remove(queue, 1)()
assert(received == editor)
-- Physical activation never changes focus or schedules restoration.
received = nil
source.forText(function(value)
  received = value
end)
assert(received == editor and focusCalls == 1 and #queue == 0)
-- Failure to restore must never fall through to copying from Stream Deck.
editor.focus = function()
  focusCalls = focusCalls + 1
end
focused, received = virtual, 'pending'
source.forText(function(value)
  received = value
end)
while #queue > 0 do
  table.remove(queue, 1)()
end
assert(received == nil)
-- Switching to another app during restoration aborts, without refocusing repeatedly.
focused, received = virtual, 'pending'
source.forText(function(value)
  received = value
end)
focused = browser
table.remove(queue, 1)()
assert(received == nil and #queue == 0)
focused, ordered, received = virtual, { virtual, deck }, 'pending'
source.forText(function(value)
  received = value
end)
assert(received == nil)
print('PASS: virtual Deck source restoration, physical focus preservation and interrupted/failed restoration.')
