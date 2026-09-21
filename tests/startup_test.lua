--- Verify physical-only startup enables IPC without loading interactive integrations.
-- @script tests.startup_test
local ipcLoads, reported = 0, 0
package.loaded['modules.config.personal'] = { data = {} }
package.loaded['modules.notifications'] = {
  error = function(key)
    assert(key == 'config.load_error')
    reported = reported + 1
  end,
}
package.preload['hs.ipc'] = function()
  ipcLoads = ipcLoads + 1
  return {}
end
-- No hs UI APIs are available: any accidental eager UI startup must fail.
hs = {}
dofile('init.lua')
assert(ipcLoads == 1 and reported == 0)
for _, name in ipairs({ 'modules.deck', 'modules.ai_text', 'modules.tasks.ui', 'modules.discord.presence' }) do
  assert(package.loaded[name] == nil, 'Unexpected eager module: ' .. name)
end
package.loaded['modules.config.personal'].loadError = true
dofile('init.lua')
assert(ipcLoads == 1 and reported == 1)
print('PASS: physical-only startup, lazy integrations and configuration error reporting.')
