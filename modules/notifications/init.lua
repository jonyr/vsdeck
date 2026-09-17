local i18n = require('modules.i18n')
local config = require('modules.config.personal').data.notifications
config = type(config) == 'table' and config or {}
local M = {}
local backends = { notify = true, alert = true, both = true }
local function tableOrEmpty(value) return type(value) == 'table' and value or {} end
local function number(value, fallback)
  return type(value) == 'number' and value >= 0 and value < math.huge and value or fallback
end
-- Raw text is reserved for external errors, custom titles and compatibility adapters.
function M.text(level, message, options)
  options = options or {}
  local settings = tableOrEmpty(tableOrEmpty(config.levels)[level])
  if config.enabled == false or settings.enabled == false then return end
  local final = options.final == true
  local backend = settings.backend or (final and config.finalBackend) or config.backend or (final and 'both' or 'notify')
  if not backends[backend] then backend = 'notify' end
  local title = options.title or config.title or 'VSDeck'
  local notification
  if backend == 'notify' or backend == 'both' then
    notification = hs.notify.new({ title = title, informativeText = message,
      withdrawAfter = number(settings.withdrawAfter, number(config.withdrawAfter, final and 0 or 5)) }):send()
  end
  if backend == 'alert' or backend == 'both' then
    local duration = number(settings.duration, number(config.duration, final and 10 or 4))
    local style = tableOrEmpty(settings.style or config.style)
    hs.alert.show(title .. '\n' .. message, style, duration)
  end
  return notification
end
for _, name in ipairs({'info', 'success', 'warning', 'error'}) do
  local level = name
  M[level] = function(key, params, options) return M.text(level, i18n.t(key, params), options) end
end
return M
