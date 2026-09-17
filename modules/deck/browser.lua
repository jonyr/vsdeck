local registry = require('modules.deck.browsers.registry')
local validation = require('modules.deck.web_validation')
local M = {}

-- Public entry point. Only validated requests reach an adapter.
function M.open(shortcut)
  local request, spec, err = validation.request(shortcut, registry)
  if not request then return false, err end
  return require(spec.adapter).open(request, spec)
end

return M
