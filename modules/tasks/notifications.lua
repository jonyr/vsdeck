--- Adapt task-specific titles and completion semantics to the central notifier.
-- @module modules.tasks.notifications

-- Compatibility adapter for custom task titles and external script output.
local notifications = require('modules.notifications')
local M = {}
--- Send task progress or a final outcome.
-- @param title User-defined task title.
-- @param message Already resolved text or external diagnostic output.
-- @param final Whether the task has reached its final outcome.
-- @param level Optional severity; final outcomes default to error unless supplied.
-- @return Native notification object when one is emitted.
function M.send(title, message, final, level)
  return notifications.text(level or (final and 'error' or 'info'), message, { title = title, final = final })
end
return M
