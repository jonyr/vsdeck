local t = require('modules.i18n').t
local M = {}
local tasks = {}

function M.launch(executable, args)
  local task
  task = hs.task.new(executable, function(code)
    tasks[task] = nil
    if code ~= 0 then
      require('modules.notifications').error('browser.exit_error', { code = code })
    end
  end, args)
  if not task then return false, t('browser.prepare_error') end
  tasks[task] = true
  if not task:start() then tasks[task] = nil; return false, t('browser.start_error') end
  return true
end

return M
