--- Launch Chromium-family browsers using explicit profile-directory arguments.
-- @module modules.deck.browsers.chromium

local t = require('modules.i18n').t
local process = require('modules.deck.browsers.process')
local M = {}

--- Open validated URLs in a new browser window.
-- @param request Validated shortcut with optional profileDirectory.
-- @param spec Browser registry entry with bundle, data and executable names.
-- @return true when launched, or false plus an error message.
function M.open(request, spec)
  local appPath = hs.application.pathForBundleID(spec.bundle)
  if not appPath then
    return false, t('browser.not_installed', { browser = spec.label })
  end
  -- Pass flags and URLs as separate arguments; profile values never become shell code.
  local args = { '--new-window' }
  if request.profileDirectory then
    local directory = os.getenv('HOME')
      .. '/Library/Application Support/'
      .. spec.data
      .. '/'
      .. request.profileDirectory
    if hs.fs.attributes(directory, 'mode') ~= 'directory' then
      return false, t('browser.profile_missing')
    end
    args[#args + 1] = '--profile-directory=' .. request.profileDirectory
  end
  for _, url in ipairs(request.urls) do
    args[#args + 1] = url
  end
  return process.launch(appPath .. '/Contents/MacOS/' .. spec.executable, args)
end

return M
