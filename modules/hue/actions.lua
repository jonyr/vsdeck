--- Build shared Hue buttons, keeping private Bridge settings in closures.
-- @module modules.hue.actions
local M = {}
local t = require('modules.i18n').t
local presets = require('modules.hue.presets')

--- Retain existing action IDs and add controls once per toggle light.
function M.build(config)
  local result, expanded = {}, {}
  local unique, count = {}, 0
  for _, light in ipairs(config.lights or {}) do
    local id = tostring(light.lightId)
    if not unique[id] then
      unique[id] = true
      count = count + 1
    end
  end
  local function add(light, id, title, badge, command)
    local action = {
      id = id,
      title = count > 1 and command ~= light and t('hue.control_title', { light = light.title, control = title })
        or title,
      badge = badge,
      category = 'Luces',
      subtitle = light.title .. ' · ' .. t('hue.operation.' .. (command.action or 'toggle')),
      keywords = 'hue luz luces color ambiente brillo',
      requiresOrigin = false,
      statusSource = 'hue',
      subscribeStatus = function(callback)
        return require('modules.hue').subscribe(callback)
      end,
      statusKey = tostring(config.bridge) .. '/' .. tostring(light.lightId),
      getStatus = function()
        return require('modules.hue').state(config, light)
      end,
      getPresentation = function()
        local hue = require('modules.hue')
        local state, data = hue.state(config, light), hue.details(config, light)
        local label = t('deck.light.' .. state)
        if state == 'on' then
          local detail = presets.describe(config, light, data)
          if detail then
            label = label .. ' · ' .. detail
          end
        end
        return {
          label = label,
          active = command.action == 'preset'
              and state == 'on'
              and presets.matches(config, light, command.preset, data)
            or false,
        }
      end,
      refreshStatus = function()
        require('modules.hue').refresh(config, light)
      end,
      run = function()
        require('modules.hue').run(config, command)
      end,
    }
    -- Only the main light button observes state; scenes and brightness stay static.
    if command ~= light then
      action.getStatus, action.getPresentation, action.refreshStatus = nil, nil, nil
      action.subscribeStatus, action.statusSource, action.statusKey = nil, nil, nil
    end
    result[#result + 1] = action
  end
  for _, light in ipairs(config.lights or {}) do
    add(light, light.id, light.title, 'HUE', light)
    local enabled = light.controls
    if enabled == nil then
      enabled = config.controls ~= false
    end
    if enabled and (light.action or 'toggle') == 'toggle' and not expanded[tostring(light.lightId)] then
      expanded[tostring(light.lightId)] = true
      local function command(action)
        return {
          lightId = light.lightId,
          title = light.title,
          action = action,
          transitionSeconds = light.transitionSeconds,
        }
      end
      for _, preset in ipairs(presets.list(config, light)) do
        local target = command('preset')
        target.preset = preset
        add(light, light.id .. '.preset.' .. preset.id, preset.title or preset.id, preset.badge or '◉', target)
      end
      for _, direction in ipairs({ { 'down', -10, '−' }, { 'up', 10, '+' } }) do
        local target = command('brightness')
        target.step = direction[2]
        add(
          light,
          light.id .. '.brightness.' .. direction[1],
          t('hue.brightness.' .. direction[1]),
          direction[3],
          target
        )
      end
    end
  end
  return result
end
return M
