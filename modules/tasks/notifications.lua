-- Compatibility adapter for custom task titles and external script output.
local notifications = require('modules.notifications')
local M = {}
function M.send(title, message, final, level)
  return notifications.text(level or (final and 'error' or 'info'), message, { title = title, final = final })
end
return M
