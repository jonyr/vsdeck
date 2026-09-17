local path = os.getenv('HOME') .. '/.config/hammerspoon/personal.lua'
local M = { path = path }
local file = io.open(path, 'r')
if not file then M.data = {}; return M end
file:close()
local chunk, err = loadfile(path)
local ok, data
if chunk then ok, data = pcall(chunk) end
if not chunk or not ok or type(data) ~= 'table' then
  hs.notify.new({title='Configuración personal', informativeText='No se pudo cargar personal.lua. Revisa su sintaxis; se usarán valores por defecto.'}):send()
  M.data = {}
else M.data = data end
return M
