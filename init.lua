--- Enable the local bridge used by the physical Stream Deck plugin.
-- @script init

-- Report configuration failures after the loader returns to avoid require cycles.
if require('modules.config.personal').loadError then
  require('modules.notifications').error('config.load_error')
end

-- Required by the plugin; no virtual deck, menu or keyboard shortcuts are started.
require('hs.ipc')
