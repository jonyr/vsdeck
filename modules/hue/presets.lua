--- Convert user-friendly presets to Hue v1 values and recognize observed scenes.
-- @module modules.hue.presets
local M = {}
local t = require('modules.i18n').t

local defaults = {
  { id = 'work', badge = '🤍', kelvin = 5000, brightness = 100 },
  { id = 'relax', badge = '🟠', kelvin = 2700, brightness = 40 },
  { id = 'cinema', badge = '🎬', hue = 240, saturation = 100, brightness = 15 },
  { id = 'gaming', badge = '🎮', hue = 280, saturation = 100, brightness = 70 },
  { id = 'red', badge = '🔴', hue = 0, saturation = 100, brightness = 40 },
  { id = 'green', badge = '🟢', hue = 120, saturation = 100, brightness = 40 },
}
local function number(value, minimum, maximum)
  return type(value) == 'number' and value == value and value >= minimum and value <= maximum
end
local function round(value)
  return math.floor(value + 0.5)
end

--- List per-light overrides, global overrides, or the six translated defaults.
function M.list(config, light)
  if light.presets then
    return light.presets
  end
  if config.presets then
    return config.presets
  end
  local result = {}
  for _, preset in ipairs(defaults) do
    local copy = {}
    for key, value in pairs(preset) do
      copy[key] = value
    end
    copy.title = t('hue.preset.' .. preset.id)
    result[#result + 1] = copy
  end
  return result
end

--- Build a validated state request using capabilities from the actual target light.
-- @return Hue payload, or nil and a localized-message key.
function M.payload(config, light, data)
  local state = data.state
  local seconds = light.transitionSeconds or config.transitionSeconds or 0.4
  if not number(seconds, 0, 10) then
    return nil, 'hue.invalid_preset'
  end
  if not number(state.bri, 1, 254) then
    return nil, 'hue.unsupported'
  end
  local body = { transitiontime = round(seconds * 10) }
  if light.action == 'brightness' then
    if not number(light.step, -100, 100) or light.step == 0 then
      return nil, 'hue.invalid_preset'
    end
    body.bri = math.max(1, math.min(254, state.bri + round(light.step * 254 / 100)))
    return body -- Brightness changes intentionally preserve power and color.
  end
  local preset = light.preset
  if type(preset) ~= 'table' or not number(preset.brightness, 1, 100) then
    return nil, 'hue.invalid_preset'
  end
  if preset.transitionSeconds ~= nil then
    if not number(preset.transitionSeconds, 0, 10) then
      return nil, 'hue.invalid_preset'
    end
    body.transitiontime = round(preset.transitionSeconds * 10)
  end
  body.on = true
  body.bri = math.max(1, round(preset.brightness * 254 / 100))
  if preset.kelvin ~= nil then
    if preset.hue ~= nil or preset.saturation ~= nil or not number(preset.kelvin, 2000, 6500) then
      return nil, 'hue.invalid_preset'
    end
    if type(state.ct) ~= 'number' then
      return nil, 'hue.unsupported'
    end
    local control = (data.capabilities or {}).control or {}
    local limits = control.ct or { min = 153, max = 500 }
    body.ct = math.max(limits.min, math.min(limits.max, round(1000000 / preset.kelvin)))
  else
    if not number(preset.hue, 0, 360) or not number(preset.saturation, 0, 100) then
      return nil, 'hue.invalid_preset'
    end
    if type(state.hue) ~= 'number' or type(state.sat) ~= 'number' then
      return nil, 'hue.unsupported'
    end
    body.hue = round(preset.hue % 360 * 65535 / 360)
    body.sat = round(preset.saturation * 254 / 100)
  end
  if state.effect ~= nil then
    body.effect = 'none'
  end
  return body
end

--- Match actual power, brightness and color, allowing Hue's integer rounding.
function M.matches(config, light, preset, data)
  if not data or not data.state.on or data.state.reachable == false then
    return false
  end
  local body =
    M.payload(config, { action = 'preset', preset = preset, transitionSeconds = light.transitionSeconds }, data)
  if not body or math.abs(data.state.bri - body.bri) > 2 then
    return false
  end
  local state = data.state
  if state.effect and state.effect ~= 'none' then
    return false
  end
  if body.ct then
    return state.colormode == 'ct' and math.abs(state.ct - body.ct) <= 2
  end
  if state.colormode ~= 'hs' then
    return false
  end
  local distance = math.abs(state.hue - body.hue)
  return math.min(distance, 65536 - distance) <= 400 and math.abs(state.sat - body.sat) <= 2
end

--- Describe observed brightness and a matching preset without relying on the last click.
function M.describe(config, light, data)
  if not data or type(data.state.bri) ~= 'number' then
    return nil
  end
  local name = t('hue.custom')
  for _, preset in ipairs(M.list(config, light)) do
    if M.matches(config, light, preset, data) then
      name = preset.title or preset.id
      break
    end
  end
  return t('hue.details', { brightness = round(data.state.bri * 100 / 254), preset = name })
end
return M
