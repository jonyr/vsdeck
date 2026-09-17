--- Validate web shortcuts and dispatch them to the registered browser adapter.
-- @module modules.deck.browser

local registry = require('modules.deck.browsers.registry')
local validation = require('modules.deck.web_validation')
local M = {}

-- Public entry point. Only validated requests reach an adapter.
--- Accept a shortcut for asynchronous opening.
-- @param shortcut Browser, profile selector and ordered URL list.
-- @return true when accepted, or false plus a validation/launch error.
-- Acceptance does not mean all tabs have finished opening.
function M.open(shortcut)
  local request, spec, err = validation.request(shortcut, registry)
  if not request then
    return false, err
  end
  return require(spec.adapter).open(request, spec)
end

return M
