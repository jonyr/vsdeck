--- Read the latest pipeline execution and all source revisions; never mutate AWS.
-- @module modules.tasks.pipelines
local i18n = require('modules.i18n')
local ui = require('modules.tasks.pipeline_ui')
local M = {}
local jobs = {}
local function t(key)
  return i18n.t('pipeline.' .. key)
end
local function valid(target)
  return type(target) == 'table'
    and type(target.profile) == 'string'
    and #target.profile <= 128
    and target.profile:match('^[%w_-]+$')
    and type(target.region) == 'string'
    and #target.region <= 64
    and (target.region == '' or target.region:match('^[a-z0-9-]+$'))
    and type(target.pipeline) == 'string'
    and #target.pipeline <= 100
    and target.pipeline:match('^[%w.@_-]+$')
    and (
      target.title == nil
      or (
        type(target.title) == 'string'
        and (utf8.len(target.title) or math.huge) <= 160
        and not target.title:find('%c')
      )
    )
end
local function key(target)
  return table.concat({ target.profile, target.region, target.pipeline }, ':')
end
--- Return only small bridge metadata; artifact payloads remain in the native UI.
function M.status(target)
  assert(valid(target), 'Invalid pipeline destination')
  local job = jobs[key(target)]
  return job and { id = job.id, state = job.state } or { state = 'idle' }
end
local function fail(job, message)
  job.state, job.reason = 'error', message
  pcall(ui.update, job)
  require('modules.notifications').text('error', message, { title = job.target.title })
end
-- Direct argv and completion-only output preserve long revision metadata without shell evaluation.
local function query(job, operation, extra, callback)
  local target = job.target
  local args = {
    'codepipeline',
    operation,
    '--profile',
    target.profile,
    '--pipeline-name',
    target.pipeline,
    '--output',
    'json',
    '--no-cli-pager',
    '--cli-connect-timeout',
    '10',
    '--cli-read-timeout',
    '30',
  }
  if target.region ~= '' then
    args[#args + 1] = '--region'
    args[#args + 1] = target.region
  end
  for _, arg in ipairs(extra) do
    args[#args + 1] = arg
  end
  local finished, timer = false, nil
  local task
  task = hs.task.new(
    require('modules.config.personal').data.awsBinary or '/opt/homebrew/bin/aws',
    function(code, stdout, stderr)
      if finished then
        return
      end
      finished = true
      if timer then
        timer:stop()
      end
      job.task, job.timer = nil, nil
      if code ~= 0 then
        fail(job, stderr ~= '' and stderr or t('failed'))
        return
      end
      local ok, data = pcall(hs.json.decode, stdout)
      if not ok or type(data) ~= 'table' then
        fail(job, t('invalid_response'))
        return
      end
      local handled, err = pcall(callback, data)
      if not handled then
        fail(job, t('invalid_response'))
        print('[pipeline] ' .. tostring(err))
      end
    end,
    args
  )
  if not task then
    fail(job, t('failed'))
    return
  end
  job.task = task
  timer = hs.timer.doAfter(60, function()
    if finished then
      return
    end
    finished = true
    job.task, job.timer = nil, nil
    task:terminate()
    fail(job, t('timeout'))
  end)
  job.timer = timer
  if not task:start() then
    finished = true
    timer:stop()
    job.task, job.timer = nil, nil
    fail(job, t('failed'))
  end
end
--- Schedule a read-only lookup; retain the chosen execution ID across both requests.
function M.start(id, target)
  assert(type(id) == 'string' and #id <= 64 and id:match('^[%w-]+$'), 'Invalid request ID')
  assert(valid(target), 'Invalid pipeline destination')
  local previous = jobs[key(target)]
  if previous and (previous.state == 'busy' or previous.id == id) then
    return M.status(target)
  end
  local copy = {
    profile = target.profile,
    region = target.region,
    pipeline = target.pipeline,
    title = target.title or target.pipeline,
  }
  local job = { id = id, state = 'busy', target = copy, artifacts = {} }
  jobs[key(target)] = job
  local opened, openError = pcall(ui.open, job)
  if not opened then
    fail(job, t('failed'))
    print('[pipeline UI] ' .. tostring(openError))
    return M.status(target)
  end
  job.timer = hs.timer.doAfter(0.1, function()
    job.timer = nil
    query(job, 'list-pipeline-executions', { '--max-items', '1', '--page-size', '1' }, function(data)
      local list = data.pipelineExecutionSummaries
      assert(type(list) == 'table', 'Missing execution summaries')
      if #list == 0 then
        job.state = 'done'
        job.empty = true
        ui.update(job)
        return
      end
      local execution = list[1].pipelineExecutionId
      assert(type(execution) == 'string' and execution:match('^[%x-]+$'), 'Invalid execution ID')
      job.executionId, job.startedAt = execution, list[1].startTime
      query(job, 'get-pipeline-execution', { '--pipeline-execution-id', execution }, function(result)
        local detail = result.pipelineExecution
        assert(type(detail) == 'table' and detail.pipelineExecutionId == execution, 'Execution mismatch')
        job.executionStatus = detail.status
        assert(detail.artifactRevisions == nil or type(detail.artifactRevisions) == 'table', 'Invalid artifacts')
        for _, artifact in ipairs(detail.artifactRevisions or {}) do
          local value = {}
          for _, field in ipairs({ 'name', 'revisionId', 'revisionSummary', 'revisionUrl' }) do
            assert(artifact[field] == nil or type(artifact[field]) == 'string', 'Invalid revision field')
            value[field] = artifact[field] or ''
          end
          job.artifacts[#job.artifacts + 1] = value
        end
        job.state = 'done'
        ui.update(job)
      end)
    end)
  end)
  return M.status(target)
end
return M
