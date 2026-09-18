--- Exercise menu-bar, webview dispatch and Escape lifecycle with fake Hammerspoon objects.
-- @script tests.deck_test
-- Test doubles keep these assertions independent of real apps and personal settings.

package.loaded['modules.config.personal'] = { data = {} }
local statusListener, polling, timerStopped, scripts
scripts = {}
package.loaded['modules.hue'] = {
  subscribe = function(fn)
    statusListener = fn
    return function()
      statusListener = nil
    end
  end,
}
local dispatch, delayed, menu, escape, focused, runs
local anchor = { x = 1100, y = 0, w = 24, h = 24 }
runs = 0
local screen = {
  frame = function()
    return { x = 0, y = 24, w = 1200, h = 876 }
  end,
}
function screen:fullFrame()
  return { x = 0, y = 0, w = 1200, h = 900 }
end
local target = {
  application = function()
    return {
      bundleID = function()
        return 'test.editor'
      end,
    }
  end,
  id = function()
    return 1
  end,
  screen = function()
    return screen
  end,
}
function target:focus()
  focused = self
end
focused = target
local v = { visible = false }
for _, name in ipairs({
  'windowStyle',
  'shadow',
  'windowTitle',
  'level',
  'allowTextEntry',
  'allowNewWindows',
  'allowNavigationGestures',
  'deleteOnClose',
  'closeOnEscape',
  'frame',
  'html',
}) do
  v[name] = function(self, value)
    self[name .. 'Value'] = value
    return self
  end
end
function v:evaluateJavaScript(script)
  scripts[#scripts + 1] = script
end
function v:windowCallback(cb)
  self.callback = cb
  return self
end
function v:show()
  self.visible = true
  return self
end
function v:hide()
  self.visible = false
  focused = target
  return self
end
function v:isVisible()
  return self.visible
end
function v:hswindow()
  return {
    focus = function()
      focused = 'deck'
    end,
  }
end
function v:delete()
  self.deleted = true
end
local function key(cb)
  return {
    enable = function(self)
      self.enabled = true
    end,
    disable = function(self)
      self.enabled = false
    end,
    delete = function() end,
    callback = cb,
  }
end
hs = {
  configdir = '.',
  notify = {
    new = function()
      return { send = function() end }
    end,
  },
  drawing = { windowLevels = { floating = 3 } },
  json = {
    encode = function()
      return '[]'
    end,
  },
  screen = {
    allScreens = function()
      return { screen }
    end,
    mainScreen = function()
      return screen
    end,
  },
  window = {
    orderedWindows = function()
      return { target }
    end,
    focusedWindow = function()
      return focused
    end,
  },
  hotkey = {
    new = function(_, _, cb)
      escape = key(cb)
      return escape
    end,
    bind = function(_, _, cb)
      return key(cb)
    end,
  },
  timer = {
    doEvery = function(_, fn)
      polling = fn
      return {
        stop = function()
          timerStopped = true
        end,
      }
    end,
    doAfter = function(_, cb)
      delayed = cb
      return { stop = function() end }
    end,
  },
  webview = {
    usercontent = {
      new = function()
        return {
          setCallback = function(self, cb)
            dispatch = cb
            return self
          end,
        }
      end,
    },
    new = function()
      return v
    end,
  },
  menubar = {
    new = function()
      menu = {}
      function menu:frame()
        return anchor
      end
      function menu:setTitle()
        return self
      end
      function menu:setTooltip()
        return self
      end
      function menu:setClickCallback(cb)
        self.click = cb
        return self
      end
      function menu:delete()
        self.deleted = true
      end
      return menu
    end,
  },
}
package.loaded['modules.deck.actions'] = {
  list = {
    {
      id = 'hue.fixture',
      title = 'Light',
      subtitle = 'Toggle',
      subscribeStatus = require('modules.hue').subscribe,
      getStatus = function()
        return 'on'
      end,
      refreshStatus = function() end,
    },
  },
  byId = {
    free = {
      requiresOrigin = false,
      run = function()
        runs = runs + 1
      end,
    },
    origin = {
      run = function(w)
        assert(w == target)
        runs = runs + 1
      end,
    },
  },
}
local deck = require('modules.deck')
deck.setupMenubar()
local first = menu
deck.setupMenubar()
assert(menu == first)
-- Opening from the menu can temporarily clear focus without closing the source.
focused = nil
menu.click()
assert(v.visible and escape.enabled)
assert(v.windowStyleValue == 0 and v.shadowValue == true and v.allowTextEntryValue == true)
assert(v.frameValue.y == 30 and v.frameValue.x + v.frameValue.w <= 1188)
dispatch({ body = { type = 'ready' } })
assert(statusListener and polling and #scripts == 1)
statusListener()
assert(#scripts == 1 and scripts[1]:find('updateDeckStates', 1, true))
-- Losing focus during an action must not close the panel or lose its Escape guard.
v.callback('focusChange', v, false)
assert(v.visible and escape.enabled)
dispatch({ body = { type = 'run', id = 'free', mode = 'copy' } })
assert(v.visible and runs == 1)
dispatch({ body = { type = 'run', id = 'origin', mode = 'replace' } })
assert(v.visible and focused == target)
delayed()
assert(runs == 2 and v.visible)
escape.callback()
assert(not v.visible and not escape.enabled)
assert(statusListener == nil and timerStopped)
menu.click()
assert(v.visible)
dispatch({ body = { type = 'close' } })
assert(not v.visible)
menu.click()
assert(v.visible)
menu.click()
assert(not v.visible)
deck.show()
v.callback('closing')
assert(not escape.enabled)
-- Recompute the anchor on every opening, including a hidden menu-bar item.
deck.hide()
anchor = { x = 500, y = 0, w = 24, h = 24 }
package.loaded['modules.config.personal'].data.webviewDeck = { menuBarGap = 0 }
deck.show()
assert(v.frameValue.x == 82 and v.frameValue.y == 24)
deck.hide()
anchor = nil
deck.show()
assert(v.frameValue.x == 170 and v.frameValue.y == 24)
deck.stop()
assert(v.deleted and menu.deleted)
print('Deck tests passed')
