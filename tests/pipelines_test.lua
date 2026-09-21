--- Read-only pipeline requests use a pinned execution, complete metadata and bounded waits.
package.path = './?.lua;./?/init.lua;' .. package.path
package.loaded['modules.config.personal'] = { data = {} }
package.loaded['modules.i18n'] = {
  t = function(key)
    return key
  end,
}
local shown, notices, calls, timers = {}, {}, {}, {}
package.loaded['modules.tasks.pipeline_ui'] = {
  open = function(job)
    shown[#shown + 1] = job
  end,
  update = function() end,
}
package.loaded['modules.notifications'] = {
  text = function(...)
    notices[#notices + 1] = { ... }
  end,
}
local spawn = true
hs = {
  json = {
    decode = function(data)
      if data == 'invalid' then
        error('invalid json')
      end
      return data
    end,
  },
  timer = {
    doAfter = function(delay, fn)
      local item = {
        delay = delay,
        fn = fn,
        stop = function(self)
          self.stopped = true
        end,
      }
      timers[#timers + 1] = item
      return item
    end,
  },
  task = {
    new = function(binary, callback, args)
      assert(binary == '/opt/homebrew/bin/aws')
      assert(
        args[1] == 'codepipeline' and (args[2] == 'list-pipeline-executions' or args[2] == 'get-pipeline-execution'),
        'only reads are allowed'
      )
      local task = {
        callback = callback,
        args = args,
        start = function()
          return spawn
        end,
        terminate = function(self)
          self.terminated = true
        end,
      }
      calls[#calls + 1] = task
      return task
    end,
  },
}
local api = require('modules.tasks.pipelines')
local target = { profile = 'work', region = '', pipeline = 'app.backend@prod', title = 'Artifacts' }
local function start(id)
  assert(api.start(id, target).state == 'busy')
  timers[#timers].fn()
  return calls[#calls]
end
local first = start('one')
api.start('two', target)
assert(#calls == 1)
local execution = '5af54d28-d9b1-474e-87c4-927d5b34c8c4'
first.callback(0, { pipelineExecutionSummaries = { { pipelineExecutionId = execution, startTime = 'today' } } }, '')
assert(#calls == 2 and calls[2].args[#calls[2].args] == execution)
local artifacts = {
  {
    name = 'app',
    revisionId = '123',
    revisionSummary = string.rep('long ', 3000),
    revisionUrl = 'https://example.com/commit/123',
  },
  { name = 'k8s', revisionId = '456' },
}
calls[2].callback(
  0,
  { pipelineExecution = { pipelineExecutionId = execution, status = 'InProgress', artifactRevisions = artifacts } },
  ''
)
assert(api.status(target).state == 'done' and #shown[1].artifacts == 2)
assert(shown[1].artifacts[1].revisionSummary == artifacts[1].revisionSummary, 'long summaries must not be truncated')
assert(shown[1].artifacts[2].revisionUrl == '')
assert(api.status(target).artifacts == nil, 'bridge responses must stay small')
api.start('one', target)
assert(#calls == 2)
start('empty').callback(0, { pipelineExecutionSummaries = {} }, '')
assert(shown[#shown].empty and api.status(target).state == 'done')
start('error').callback(1, '', 'ExpiredToken')
assert(api.status(target).state == 'error' and shown[#shown].reason == 'ExpiredToken')
start('invalid').callback(0, 'invalid', '')
assert(api.status(target).state == 'error')
local late = start('timeout')
timers[#timers].fn()
assert(late.terminated and api.status(target).state == 'error')
local count = #calls
late.callback(0, { pipelineExecutionSummaries = { { pipelineExecutionId = execution } } }, '')
assert(#calls == count, 'late response after timeout must not issue another request')
spawn = false
api.start('spawn', target)
timers[#timers].fn()
assert(api.status(target).state == 'error')
assert(not pcall(api.start, 'bad', { profile = 'work', region = '', pipeline = 'x;touch /tmp/test' }))
print(
  'PASS: pipeline read-only calls, pinned execution, all artifacts, long output, duplicate guard, empty, error and timeout.'
)
