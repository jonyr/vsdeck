--- Execute personal shell scripts with duplicate guards and bounded progress output.
-- @module modules.tasks.runner

local t = require('modules.i18n').t
local M = {}
-- Retain running processes independently of the last display state.
local active = {}
local notify = require('modules.tasks.notifications').send

--- Start one script with separate, non-interpolated arguments.
-- @param job id/title/script, optional args, cwd, env overrides and timeout seconds.
-- buffered disables streaming; outputLimit bounds the captured completion output.
-- The legacy progress callback receives streamed stdout; stream(stdout, stderr) also receives final tails.
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
  local finished, timedOut = false, false
  local timer
  local function completed(code, stdout, stderr)
    finished = true
    if timer then
      timer:stop()
    end
    if job.stream then
      job.stream(stdout or '', stderr or '')
    end
    -- Completion contains only unread tails; streaming has already consumed earlier chunks.
    output = (output .. (stdout or '')):sub(-(job.outputLimit or 8192))
    errors = (errors .. (stderr or '')):sub(-(job.outputLimit or 8192))
    active[job.id] = nil
    if callback then
      callback(timedOut and 124 or code, output, errors)
    else
      notify(
        job.title,
        code == 0 and t('tasks.completed') or t('tasks.failed'),
        true,
        code == 0 and 'success' or 'error'
      )
    end
  end
  local function streamed(_, stdout, stderr)
    -- Hammerspoon can deliver a final stream callback after completion.
    if finished then
      return false
    end
    if job.stream then
      job.stream(stdout or '', stderr or '')
    end
    if stderr and stderr ~= '' then
      errors = (errors .. stderr):sub(-(job.outputLimit or 8192))
    end
    if stdout and stdout ~= '' then
      output = (output .. stdout):sub(-(job.outputLimit or 8192))
      if job.progress then
        job.progress(stdout)
      end
    end
    return true
  end
  -- Short machine-readable queries must not race a final stream callback that
  -- Hammerspoon may deliver after termination. Buffered tasks have one output owner.
  local task
  if job.buffered then
    task = hs.task.new('/bin/bash', completed, args)
  else
    task = hs.task.new('/bin/bash', completed, streamed, args)
  end
  if not task then
    notify(job.title, t('tasks.prepare_error'), false, 'error')
    return false
  end
  if job.cwd and not task:setWorkingDirectory(job.cwd) then
    notify(job.title, t('tasks.prepare_error'), false, 'error')
    return false
  end
  if job.env then
    local environment = task:environment()
    for key, value in pairs(job.env) do
      environment[key] = value
    end
    if not task:setEnvironment(environment) then
      return false
    end
  end
  active[job.id] = task
  if not task:start() then
    active[job.id] = nil
    notify(job.title, t('tasks.start_error'), false, 'error')
    return false
  end
  if job.timeout and not finished then
    timer = hs.timer.doAfter(job.timeout, function()
      timedOut = true
      task:terminate()
    end)
  end
  return true
end

return M
