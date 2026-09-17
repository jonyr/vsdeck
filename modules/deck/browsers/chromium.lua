local t = require('modules.i18n').t
local process = require('modules.deck.browsers.process')
local M = {}

function M.open(request, spec)
  local appPath = hs.application.pathForBundleID(spec.bundle)
  if not appPath then return false, t('browser.not_installed', { browser = spec.label }) end
  local args = { '--new-window' }
  if request.profileDirectory then
    local directory = os.getenv('HOME') .. '/Library/Application Support/' .. spec.data .. '/' .. request.profileDirectory
    if hs.fs.attributes(directory, 'mode') ~= 'directory' then
      return false, t('browser.profile_missing')
    end
    args[#args + 1] = '--profile-directory=' .. request.profileDirectory
  end
  for _, url in ipairs(request.urls) do args[#args + 1] = url end
  return process.launch(appPath .. '/Contents/MacOS/' .. spec.executable, args)
end

return M
