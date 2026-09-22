--- Execute personal shell scripts with duplicate guards and bounded progress output.
-- @module modules.tasks.runner

local t = require('modules.i18n').t
local M = {}
-- Retain running processes independently of the last display state.
local active = {}
local notify = require('modules.tasks.notifications').send

--- Start one script with separate, non-interpolated arguments.
-- @param job Table containing id, title, script, optional args and progress callback.
-- @param callback Optional completion handler receiving code, output and stderr.
-- @return true when started, false when rejected; completion is asynchronous.
function M.run(job, callback)
  if active[job.id] then
    notify(job.title, t('tasks.busy'), false, 'warning')
    return false
  end
  local args = { job.script }
  for _, value in ipairs(job.args or {}) do
    if type(value) ~= 'string' then
      notify(job.title, t('tasks.arguments'), false, 'error')
      return false
    end
    args[#args + 1] = value
  end
  -- Bound accumulated progress output while preserving the latest diagnostic context.
  local output, errors = '', ''
  local finished = false
  local task = hs.task.new('/bin/bash', function(code, stdout, stderr)
    finished = true
    -- Completion contains only unread tails; streaming has already consumed earlier chunks.
    output = (output .. (stdout or '')):sub(-8192)
    errors = (errors .. (stderr or '')):sub(-8192)
    active[job.id] = nil
    if callback then
      callback(code, output, errors)
    else
      notify(
        job.title,
        code == 0 and t('tasks.completed') or t('tasks.failed'),
        true,
        code == 0 and 'success' or 'error'
      )
    end
  end, function(_, stdout, stderr)
    -- Hammerspoon can deliver a final stream callback after completion.
    if finished then
      return false
    end
    if stderr and stderr ~= '' then
      errors = (errors .. stderr):sub(-8192)
    end
    if stdout and stdout ~= '' then
      output = (output .. stdout):sub(-8192)
      if job.progress then
        job.progress(stdout)
      end
    end
    return true
  end, args)
  if not task then
    notify(job.title, t('tasks.prepare_error'), false, 'error')
    return false
  end
  active[job.id] = task
  if not task:start() then
    active[job.id] = nil
    notify(job.title, t('tasks.start_error'), false, 'error')
    return false
  end
  return true
end

return M
