local M = {}
local tasks = {}

function M.launch(executable, args)
  local task
  task = hs.task.new(executable, function(code)
    tasks[task] = nil
    if code ~= 0 then
      hs.notify.new({ title = 'Deck · Web', informativeText = 'El navegador terminó con un error (' .. tostring(code) .. ').' }):send()
    end
  end, args)
  if not task then return false, 'No se pudo preparar la apertura del navegador.' end
  tasks[task] = true
  if not task:start() then tasks[task] = nil; return false, 'No se pudo iniciar el navegador.' end
  return true
end

return M
