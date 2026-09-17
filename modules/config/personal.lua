--- Load trusted installation settings without coupling the loader to UI services.
-- @module modules.config.personal

-- This is trusted executable Lua; a missing file means an optional empty configuration.
local path = os.getenv('HOME') .. '/.config/hammerspoon/personal.lua'
local M = { path = path }
local file = io.open(path, 'r')
if not file then M.data = {}; return M end
file:close()
-- Defer user notification to startup so localization can depend on this loader safely.
local chunk = loadfile(path)
local ok, data
if chunk then ok, data = pcall(chunk) end
if not chunk or not ok or type(data) ~= 'table' then
  M.loadError = true -- Report after configuration and notification modules are initialized.
  M.data = {}
else M.data = data end
return M
