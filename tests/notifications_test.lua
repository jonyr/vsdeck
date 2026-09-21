--- Preserve task progress and final-outcome notification semantics.
-- @script tests.notifications_test
-- Test doubles keep these assertions independent of real apps and personal settings.

package.loaded['modules.config.personal'] = { data = {} }
package.path = './?.lua;./?/init.lua;' .. package.path
local attributes, alerts = {}, 0
hs = {
  notify = {
    new = function(a)
      attributes[#attributes + 1] = a
      return {
        send = function(self)
          return self
        end,
      }
    end,
  },
  alert = {
    show = function(_, style, duration)
      assert(duration == 10)
      alerts = alerts + 1
    end,
  },
}
local n = require('modules.tasks.notifications')
n.send('Progress', 'Waiting')
assert(attributes[1].withdrawAfter == 5 and alerts == 0)
n.send('Done', 'Available', true)
assert(attributes[2].withdrawAfter == 0 and alerts == 1)
n.send('Error', 'Wait failed', true)
assert(attributes[3].withdrawAfter == 0 and alerts == 2)
print('PASS: transient progress, persistent final outcomes and visible fallback.')

local central = require('modules.notifications')
local shown = false
central.text('success', 'Complete', {
  present = function()
    shown = true
  end,
})
assert(shown and #attributes == 3, 'custom task presenter must not duplicate native notifications')
central.text('error', 'Failure', {
  present = function()
    error('window failed')
  end,
})
assert(#attributes == 4, 'broken presenter must fall back to native delivery')
