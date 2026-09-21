--- Adapt read-only pipeline queries to the shared task center.
-- @module modules.tasks.pipeline_ui
local center = require('modules.tasks.ui')
local M = {}
function M.open(job)
  job.kind, job.phase = 'pipeline', 'pipeline_read'
  center.register(job, job.target, 'physical')
  center.reveal(job)
end
function M.update(job)
  center.update(job)
end
return M
