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
