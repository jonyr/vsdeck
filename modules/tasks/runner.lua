local M = { states = {} }
local active = {}
local notify = require('modules.tasks.notifications').send
function M.isRunning(id) return active[id] ~= nil end
function M.run(job, callback)
  if active[job.id] then notify(job.title, 'Esta tarea ya está en ejecución.'); return false end
  local args = { job.script }
  for _, value in ipairs(job.args or {}) do
    if type(value) ~= 'string' then notify(job.title, 'Los argumentos deben ser cadenas.'); return false end
    args[#args+1] = value
  end
  local output, task = '', nil
  task = hs.task.new('/bin/bash', function(code, stdout, stderr)
    active[job.id] = nil
    M.states[job.id] = code == 0 and 'Completado' or 'Error'
    if callback then callback(code, output ~= '' and output or stdout, stderr)
    else notify(job.title, code == 0 and 'Tarea completada.' or 'La tarea terminó con error. Revisa el script desde tu terminal.', true) end
  end, function(_, stdout)
    if stdout and stdout ~= '' then
      output = (output .. stdout):sub(-8192)
      if job.progress then job.progress(stdout) end
    end
    return true
  end, args)
  if not task then notify(job.title, 'No se pudo preparar la tarea.'); return false end
  active[job.id] = task
  M.states[job.id] = 'Ejecutando'
  if not task:start() then active[job.id] = nil; M.states[job.id] = 'Error'; notify(job.title, 'No se pudo iniciar la tarea.'); return false end
  return true
end
function M.confirmScript(job)
  if job.confirm ~= false then
    local choice = hs.dialog.blockAlert(job.title, 'Ejecutar script:\n' .. job.script, 'Ejecutar', 'Cancelar')
    if choice ~= 'Ejecutar' then return end
  end
  return M.run(job)
end
return M
