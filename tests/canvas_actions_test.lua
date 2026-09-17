--- Exercise pagination, output modes and focus guards with a retained Canvas double.
-- @script tests.canvas_actions_test
-- Test doubles keep these assertions independent of real apps and personal settings.

local current, delayed, focused, received
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
}
function target:focus()
  focused = self
end
focused = target
local function noop() end
hs = {
  screen = {
    mainScreen = function()
      return {
        frame = function()
          return { x = 0, y = 25, w = 1200, h = 800 }
        end,
      }
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
  notify = {
    new = function()
      return { send = noop }
    end,
  },
  timer = {
    doAfter = function(_, cb)
      delayed = cb
      return { stop = noop }
    end,
  },
  hotkey = {
    new = function()
      return { enable = noop, disable = noop, delete = noop }
    end,
  },
  canvas = {
    windowLevels = { floating = 3 },
    new = function(frame)
      local c = { elements = {}, visible = false }
      function c:level()
        return self
      end
      function c:clickActivating()
        return self
      end
      function c:appendElements(e)
        table.insert(self.elements, e)
      end
      function c:elementCount()
        return #self.elements
      end
      function c:mouseCallback(cb)
        self.click = cb
      end
      function c:elementAttribute() end
      function c:isShowing()
        return self.visible
      end
      function c:show()
        self.visible = true
      end
      function c:hide()
        self.visible = false
      end
      function c:delete()
        self.visible = false
      end
      current = c
      return c
    end,
  },
}
local actions = {}
for i = 1, 16 do
  actions[i] = {
    title = 'Action ' .. i,
    badge = 'A',
    category = 'Texto',
    run = function(w, m)
      received = { i, w, m }
    end,
  }
end
package.loaded['modules.deck.actions'] = { list = actions }
package.loaded['modules.config.personal'] = { data = {} }
local deck = require('modules.deck.canvas_demo')
deck.show()
local first = current
current.click(nil, 'mouseUp', 'next')
assert(current ~= first)
current.click(nil, 'mouseUp', 'tile11')
delayed()
assert(received[1] == 11 and received[2] == target and received[3] == 'replace')
assert(current.visible)
current.click(nil, 'mouseUp', 'mode')
current.click(nil, 'mouseUp', 'tile11')
delayed()
assert(received[3] == 'copy')
actions[12].requiresOrigin = false
current.click(nil, 'mouseUp', 'tile12')
assert(received[1] == 12 and received[2] == nil)
-- A focus change before the delayed callback must prevent dispatch.
received = nil
current.click(nil, 'mouseUp', 'tile11')
focused = {}
delayed()
assert(received == nil)
current.click(nil, 'mouseUp', 'close')
assert(not current.visible)
print('Canvas shared actions tests passed')
