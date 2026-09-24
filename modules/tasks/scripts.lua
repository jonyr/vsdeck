--- Run configurable scripts and interpret their optional versioned option/event protocol.
-- @module modules.tasks.scripts
local runner = require('modules.tasks.runner')
local ui = require('modules.tasks.ui')
local notifications = require('modules.notifications')
local i18n = require('modules.i18n')
local personal = require('modules.config.personal').data
local M = {}
local jobs, locks = {}, {}
local function t(key)
  return i18n.t('task_ui.script_' .. key)
end
local function clean(value)
  return tostring(value or ''):gsub('\27%[[%d;]*[A-Za-z]', ''):gsub('[%z\1-\8\11-\31\127]', '')
end
local function validString(value, maximum)
  return type(value) == 'string' and #value <= maximum and not value:find('%z')
end
local function decode(value, fallback)
  if value == nil or value == '' then
    return fallback
  end
  assert(type(value) == 'string' and #value <= 8192, t('invalid'))
  local ok, result = pcall(hs.json.decode, value)
  assert(ok and type(result) == 'table', t('invalid'))
  return result
end
local function resolve(target)
  assert(type(target) == 'table' and validString(target.script, 4096), t('invalid'))
  local profile = (personal.scriptTasks or {})[target.script] or {}
  local script = profile.script or target.script
  local cwd = target.cwd ~= '' and target.cwd or nil
  cwd = cwd or profile.cwd or script:match('^(.*)/[^/]+$')
  assert(script:sub(1, 1) == '/' and cwd and cwd:sub(1, 1) == '/', t('invalid'))
  local args = decode(target.args, {})
  assert(#args <= 64, t('invalid'))
  for key, value in pairs(args) do
    assert(
      type(key) == 'number' and key >= 1 and key <= #args and key % 1 == 0 and validString(value, 4096),
      t('invalid')
    )
  end
  local selection = decode(target.selection, {})
  for key, value in pairs(selection) do
    assert(type(key) == 'string' and key:match('^[%a][%w_-]*$') and validString(value, 1024), t('invalid'))
  end
  local mode = target.mode or 'options'
  assert(mode == 'options' or mode == 'direct', t('invalid'))
  local title = target.title ~= '' and target.title or nil
  assert(title == nil or validString(title, 160), t('invalid'))
  return {
    script = script,
    cwd = cwd,
    args = args,
    selection = selection,
    mode = mode,
    title = title or target.script,
    env = profile.env,
    resources = profile.resources,
  }
end
local function key(target)
  return hs.json.encode({
    target.script,
    target.cwd or '',
    target.args or '',
    target.mode or 'options',
    target.selection or '',
  })
end
local function finish(job, state, message)
  job.state, job.phase, job.message = state, state, clean(message)
  if job.lock then
    locks[job.lock] = nil
    job.lock = nil
  end
  pcall(ui.update, job)
  if state ~= 'cancelled' then
    notifications.text(state == 'done' and 'success' or 'error', job.message, {
      title = job.title,
      final = true,
      present = function()
        ui.toast(job)
      end,
    })
  end
end
local function descriptor(data)
  assert(
    type(data) == 'table' and data.version == 1 and type(data.inputs) == 'table' and #data.inputs <= 12,
    t('invalid')
  )
  local names = {}
  for _, input in ipairs(data.inputs) do
    assert(
      type(input) == 'table'
        and input.type == 'select'
        and type(input.name) == 'string'
        and input.name:match('^[%a][%w_-]*$')
        and #input.name <= 64
        and not names[input.name],
      t('invalid')
    )
    names[input.name] = true
    assert(
      validString(input.label, 160) and type(input.options) == 'table' and #input.options > 0 and #input.options <= 100,
      t('invalid')
    )
    local values = {}
    for _, option in ipairs(input.options) do
      assert(
        type(option) == 'table'
          and validString(option.value, 1024)
          and validString(option.label, 160)
          and not values[option.value],
        t('invalid')
      )
      values[option.value] = true
    end
  end
  return data.inputs
end
local function execute(job, values)
  local target, args, labels = job.target, {}, {}
  for _, arg in ipairs(target.args) do
    args[#args + 1] = arg
  end
  if target.mode == 'options' then
    args[#args + 1] = '--run'
    for _, input in ipairs(job.inputs) do
      local value, valid = values[input.name], false
      for _, option in ipairs(input.options) do
        if option.value == value then
          valid = true
          labels[#labels + 1] = input.label .. ': ' .. option.label
        end
      end
      if not valid then
        finish(job, 'error', t('invalid'))
        return
      end
      args[#args + 1], args[#args + 2] = '--' .. input.name, value
    end
  end
  job.name = table.concat(labels, ' · ')
  local resource = target.cwd
  for name, mapping in pairs(target.resources or {}) do
    if type(mapping) == 'table' and mapping[values[name]] then
      resource = mapping[values[name]]
      break
    end
  end
  resource = hs.fs.pathToAbsolute(resource)
  if not resource then
    finish(job, 'error', t('invalid'))
    return
  end
  if locks[resource] then
    finish(job, 'error', t('busy'))
    return
  end
  locks[resource], job.lock = job, resource
  job.phase, job.message = 'script_running', t('running')
  pcall(ui.update, job)
  local pending, result = '', nil
  local function line(text)
    text = clean(text)
    if text:sub(1, 13) == 'VSDECK_EVENT ' then
      local ok, event = pcall(hs.json.decode, text:sub(14))
      if ok and type(event) == 'table' and validString(event.message, 2048) then
        if event.type == 'progress' then
          job.message = clean(event.message)
        elseif event.type == 'result' then
          result = clean(event.message)
        end
      end
    else
      job.logs = ((job.logs or '') .. text .. '\n'):sub(-32768)
      if text ~= '' then
        job.message = text:sub(1, 500)
      end
    end
  end
  local accepted = runner.run({
    id = 'script:' .. job.uid,
    title = job.title,
    script = target.script,
    cwd = target.cwd,
    env = target.env,
    args = args,
    stream = function(stdout, stderr)
      pending = pending .. stdout
      while true do
        local boundary = pending:find('\n', 1, true)
        if not boundary then
          break
        end
        line(pending:sub(1, boundary - 1))
        pending = pending:sub(boundary + 1)
      end
      if #pending > 32768 then
        line(pending:sub(1, 32768))
        pending = ''
      end
      if stderr ~= '' then
        job.logs = ((job.logs or '') .. clean(stderr)):sub(-32768)
      end
      pcall(ui.update, job)
    end,
  }, function(code, _, stderr)
    if pending ~= '' then
      line(pending)
    end
    job.reason = code ~= 0 and clean(stderr) or nil
    finish(job, code == 0 and 'done' or 'error', code == 0 and (result or t('done')) or t('error'))
  end)
  if not accepted then
    finish(job, 'error', t('error'))
  end
end
--- Read local state only; polling never executes a script.
function M.status(target)
  local job = jobs[key(target)]
  return { state = job and job.state or 'idle' }
end
--- Inspect options, collect a selection, then execute once asynchronously.
function M.start(id, raw)
  assert(validString(id, 64) and id:match('^[%w-]+$'), t('invalid'))
  local target, identity = resolve(raw), key(raw)
  if jobs[identity] and (jobs[identity].state == 'busy' or jobs[identity].requestId == id) then
    return M.status(raw)
  end
  local job = {
    requestId = id,
    kind = 'script',
    state = 'busy',
    phase = 'script_describe',
    message = t('describe'),
    target = target,
  }
  jobs[identity] = job
  local opened = pcall(function()
    ui.register(job, target, 'physical')
    ui.reveal(job)
  end)
  if not opened then
    finish(job, 'error', i18n.t('task_ui.unavailable'))
    return M.status(raw)
  end
  if not hs.fs.attributes(target.script, 'mode') or not hs.fs.attributes(target.cwd, 'mode') then
    finish(job, 'error', t('invalid'))
    return M.status(raw)
  end
  if target.mode == 'direct' then
    execute(job, {})
    return M.status(raw)
  end
  local args, output, overflow = {}, '', false
  for _, arg in ipairs(target.args) do
    args[#args + 1] = arg
  end
  args[#args + 1] = '--describe'
  local accepted = runner.run({
    id = 'describe:' .. job.uid,
    title = job.title,
    script = target.script,
    cwd = target.cwd,
    env = target.env,
    args = args,
    timeout = 15,
    buffered = true,
    outputLimit = 65537,
    stream = function(stdout)
      output = output .. stdout
      if #output > 65536 then
        overflow = true
        output = output:sub(1, 65536)
      end
    end,
  }, function(code, _, stderr)
    local ok, inputs = pcall(function()
      assert(code == 0 and not overflow, t('invalid'))
      return descriptor(hs.json.decode(output))
    end)
    if not ok then
      job.reason = clean(stderr ~= '' and stderr or tostring(inputs))
      finish(job, 'error', t('invalid'))
      return
    end
    job.inputs = inputs
    local complete, known = true, {}
    for _, input in ipairs(inputs) do
      known[input.name] = true
      if target.selection[input.name] == nil then
        complete = false
      end
    end
    for name in pairs(target.selection) do
      if not known[name] then
        finish(job, 'error', t('invalid'))
        return
      end
    end
    if complete then
      execute(job, target.selection)
      return
    end
    job.phase, job.message, job.selection = 'confirm', t('select'), target.selection
    ui.confirm(job, function(acceptedChoice, values)
      if acceptedChoice then
        execute(job, type(values) == 'table' and values or {})
      else
        finish(job, 'cancelled', t('cancelled'))
      end
    end)
  end)
  if not accepted then
    finish(job, 'error', t('error'))
  end
  return M.status(raw)
end
return M
