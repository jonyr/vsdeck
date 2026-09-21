--- Inspect, confirm and request RDS snapshots through the shared task runner.
-- @module modules.tasks.snapshots

local t = require('modules.i18n').t
local runner = require('modules.tasks.runner')
local M = {}
local ui = require('modules.tasks.ui')
local notify = require('modules.tasks.notifications').send
local jobs, scheduled = {}, {}

local function key(target)
  return table.concat({ target.profile or '', target.region or '', target.instance or '' }, ':')
end

local function valid(target)
  return type(target) == 'table'
    and type(target.profile) == 'string'
    and #target.profile <= 128
    and target.profile:match('^[%w_-]+$')
    and type(target.region) == 'string'
    and #target.region <= 64
    and target.region:match('^[a-z0-9-]+$')
    and type(target.instance) == 'string'
    and #target.instance <= 63
    and target.instance:match('^[a-zA-Z][a-zA-Z0-9-]*$')
    and not target.instance:find('--', 1, true)
    and target.instance:sub(-1) ~= '-'
    and (
      target.title == nil
      or (
        type(target.title) == 'string'
        and (utf8.len(target.title) or math.huge) <= 160
        and not target.title:find('%c')
      )
    )
end

--- Return shared progress for a destination, regardless of which deck launched it.
function M.status(target)
  assert(valid(target), 'Invalid snapshot destination')
  local job = jobs[key(target)]
  return job or { state = 'idle', phase = 'idle' }
end

local function execute(target, job)
  local function update(state, phase, reason)
    job.state, job.phase, job.reason = state, phase, reason or ''
    local ok, err = pcall(ui.update, job)
    if not ok then
      print('[snapshot UI] ' .. tostring(err))
    end
  end
  local config = require('modules.config.personal').data
  local script = hs.configdir .. '/scripts/rds-snapshot.sh'
  local args =
    { 'inspect', config.awsBinary or '/opt/homebrew/bin/aws', target.profile, target.region, target.instance }
  local function failure(message)
    update('error', 'error', message)
    require('modules.notifications').text('error', message, {
      title = target.title,
      final = true,
      present = function()
        ui.toast(job)
      end,
    })
  end
  update('busy', 'inspect')
  local accepted = runner.run(
    { id = target.id, title = target.title, script = script, args = args },
    function(code, stdout, stderr)
      if code ~= 0 then
        failure(stderr ~= '' and stderr or t('snapshot.verify_error'))
        return
      end
      local account = (stdout or ''):match('^%s*(%d+)%s*$')
      if not account or #account ~= 12 then
        failure(t('snapshot.account_error'))
        return
      end
      local name = target.instance .. '-' .. os.date('%Y%m%d-%H%M') .. '-manual'
      job.name = name
      update('busy', 'confirm')
      job.account = account
      local function confirmed(acceptedChoice)
        if job.phase ~= 'confirm' then
          return
        end
        if not acceptedChoice then
          runner.states[target.id] = 'Cancelado'
          update('cancelled', 'cancelled')
          return
        end
        args[1], args[6], args[7] = 'create', name, account
        update('busy', 'create')
        local started = runner.run({
          id = target.id,
          title = target.title,
          script = script,
          args = args,
          progress = function(text)
            if text:find('Solicitado:', 1, true) then
              update('busy', 'waiting')
            end
          end,
        }, function(exit, _, errorText)
          if exit ~= 0 then
            failure(errorText ~= '' and errorText or t('snapshot.unconfirmed'))
          else
            update('done', 'available')
            require('modules.notifications').text('success', t('snapshot.available', { name = name }), {
              title = target.title,
              final = true,
              present = function()
                ui.toast(job)
              end,
            })
          end
        end)
        if not started then
          failure(t('tasks.start_error'))
        end
      end
      local shown, err = pcall(ui.confirm, job, function(choice)
        local ok, callbackError = pcall(confirmed, choice)
        if not ok then
          failure(t('snapshot.verify_error'))
          print('[snapshot] ' .. tostring(callbackError))
        end
      end)
      if not shown then
        failure(t('task_ui.unavailable'))
        print('[snapshot UI] ' .. tostring(err))
      end
    end
  )
  if not accepted then
    failure(t('tasks.start_error'))
  end
end

local function begin(target, requestId, deferred)
  assert(valid(target), 'Invalid snapshot destination')
  local destination = key(target)
  local previous = jobs[destination]
  if scheduled[destination] then
    return previous
  end
  if previous and (previous.state == 'busy' or (requestId and previous.id == requestId)) then
    return previous
  end
  local copy = {
    profile = target.profile,
    region = target.region,
    instance = target.instance,
    title = target.title or t('snapshot.create'),
    id = target.id or ('snapshot:' .. destination),
  }
  local job = { id = requestId or '', state = 'busy', phase = 'queued', reason = '' }
  jobs[destination] = job
  local registered, registrationError = pcall(ui.register, job, copy, 'physical')
  if not registered then
    job.state, job.phase, job.reason = 'error', 'error', t('task_ui.unavailable')
    notify(copy.title, job.reason, true, 'error')
    print('[snapshot UI] ' .. tostring(registrationError))
    return job
  end
  local function run()
    scheduled[destination] = nil
    local ok, err = pcall(execute, copy, job)
    if not ok then
      job.state, job.phase, job.reason = 'error', 'error', t('snapshot.verify_error')
      pcall(ui.update, job)
      job.diagnostic = tostring(err)
      print('[snapshot] ' .. job.diagnostic)
      notify(copy.title, job.reason, true, 'error')
    end
  end
  if deferred then
    scheduled[destination] = hs.timer.doAfter(0.1, run)
  else
    run()
  end
  return job
end

--- Accept a Stream Deck request without blocking its CLI connection on confirmation.
function M.start(id, target)
  assert(type(id) == 'string' and #id <= 64 and id:match('^[%w-]+$'), 'Invalid request ID')
  return begin(target, id, true)
end

--- Inspect the AWS identity before presenting the snapshot confirmation.
-- @param target Snapshot metadata with id, title, profile, region and instance.
-- The shell script rechecks the confirmed account before creating a snapshot.
function M.run(target)
  if not valid(target) then
    notify(
      type(target) == 'table' and target.title or t('snapshot.create'),
      t('snapshot.destination'),
      false,
      'warning'
    )
    return
  end
  if M.status(target).state == 'busy' then
    notify(target.title, t('snapshot.busy'), false, 'warning')
  end
  return begin(target, nil, false)
end

return M
