--- Retain asynchronous browser processes until their completion callbacks run.
-- @module modules.deck.browsers.process

local t = require('modules.i18n').t
local M = {}
-- The table is a lifetime anchor, not a queryable queue: retain each hs.task until completion.
local tasks = {} -- luacheck: ignore 241 (strong references keep asynchronous tasks alive)

--- Launch an executable without shell interpolation.
-- @param executable Absolute executable path.
-- @param args Array of separate process arguments.
-- @return true when started, or false plus an error message.
function M.launch(executable, args)
  local task
  task = hs.task.new(executable, function(code)
    tasks[task] = nil
    if code ~= 0 then
      require('modules.notifications').error('browser.exit_error', { code = code })
    end
  end, args)
  if not task then
    return false, t('browser.prepare_error')
  end
  tasks[task] = true
  if not task:start() then
    tasks[task] = nil
    return false, t('browser.start_error')
  end
  return true
end

return M
