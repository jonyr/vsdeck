-- Shared dispatch rules for the HTML and Canvas interfaces.
local M = {}
function M.new()
  local timer
  local self = {}
  local function notify(message)
    hs.notify.new({title='Deck', informativeText=message}):send()
  end
  function self.isBusy() return timer ~= nil end
  function self.cancel()
    if timer then timer:stop(); timer=nil end
  end
  function self.run(action, target, mode)
    if timer or not action or (mode ~= 'copy' and mode ~= 'replace') then return end
    if action.requiresOrigin == false then
      if not pcall(action.run) then notify('No se pudo ejecutar la acción.') end
      return
    end
    if not target or not target:id() then notify('No hay una ventana de origen disponible.'); return end
    target:focus()
    timer = hs.timer.doAfter(0.2, function()
      timer=nil
      if hs.window.focusedWindow() ~= target then
        notify('No se pudo recuperar la ventana de origen.'); return
      end
      if not pcall(action.run, target, mode) then notify('No se pudo ejecutar la acción.') end
    end)
  end
  return self
end
return M
