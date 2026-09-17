local path = os.getenv('HOME') .. '/.config/hammerspoon/personal.lua'
local M = { path = path }
local file = io.open(path, 'r')
if not file then M.data = {}; return M end
file:close()
local chunk, err = loadfile(path)
local ok, data
if chunk then ok, data = pcall(chunk) end
if not chunk or not ok or type(data) ~= 'table' then
  M.loadError = true -- Report after configuration and notification modules are initialized.
  M.data = {}
else M.data = data end
return M
