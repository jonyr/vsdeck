--- Control Hue lights asynchronously using a Bridge key stored in macOS Keychain.
-- @module modules.hue.init

local t = require('modules.i18n').t
-- Hue local API v1. Credentials stay in Keychain, never in action metadata.
local notifications = require('modules.notifications')
local M = {}
-- Entries serialize operations per bridge/light pair and invalidate late callbacks.
local pending = {}
local function validBridge(value)
  if type(value) ~= 'string' then
    return false
  end
  local count = 0
  for part in value:gmatch('[^.]+') do
    if not part:match('^%d+$') or tonumber(part) > 255 then
      return false
    end
    count = count + 1
  end
  return count == 4 and value:match('^%d+%.%d+%.%d+%.%d+$') ~= nil
end

--- Start a guarded read/modify/write operation for one light.
-- @param config Hue settings with a numeric IPv4 bridge address.
-- @param light Light metadata with lightId and toggle/on/off action.
-- Completion is notified; duplicate requests for the same light are ignored.
function M.run(config, light)
  if not validBridge(config.bridge) or not tostring(light.lightId):match('^%d+$') then
    notifications.warning('hue.config')
    return
  end
  local operation = light.action or 'toggle'
  if operation ~= 'toggle' and operation ~= 'on' and operation ~= 'off' then
    notifications.warning('hue.action')
    return
  end
  local id = config.bridge .. '/' .. tostring(light.lightId)
  if pending[id] then
    notifications.info('hue.busy')
    return
  end
  local entry = {}
  pending[id] = entry
  -- Completion and timeout share cleanup so a late response cannot notify twice.
  local function finish(message, level)
    if pending[id] ~= entry then
      return
    end
    pending[id] = nil
    if entry.timer then
      entry.timer:stop()
    end
    notifications.text(level or 'error', message)
  end
  local function request(method, url, body, callback)
    hs.http.doAsyncRequest(url, method, body, { ['Content-Type'] = 'application/json' }, function(status, raw)
      if pending[id] ~= entry then
        return
      end
      if status ~= 200 then
        finish(t('hue.contact'))
        return
      end
      local ok, data = pcall(hs.json.decode, raw)
      if not ok or type(data) ~= 'table' then
        finish(t('hue.response'))
        return
      end
      for _, item in ipairs(data) do
        if item.error then
          finish(t('hue.rejected'))
          return
        end
      end
      callback(data)
    end)
  end
  entry.timer = hs.timer.doAfter(20, function()
    finish(t('hue.timeout'))
  end)
  -- Read the secret through Keychain and keep it out of public action metadata.
  entry.task = hs.task.new('/usr/bin/security', function(code, stdout)
    if pending[id] ~= entry then
      return
    end
    local key = (stdout or ''):gsub('%s+$', '')
    if code ~= 0 or not key:match('^[%w%-]+$') then
      finish(t('hue.key_read'))
      return
    end
    local url = 'http://' .. config.bridge .. '/api/' .. key .. '/lights/' .. tostring(light.lightId)
    request('GET', url, nil, function(data)
      if not data.state or type(data.state.on) ~= 'boolean' then
        finish(t('hue.unknown'))
        return
      end
      if data.state.reachable == false then
        finish(t('hue.unreachable'))
        return
      end
      local desired = operation == 'on' or (operation == 'toggle' and not data.state.on)
      request('PUT', url .. '/state', hs.json.encode({ on = desired }), function(result)
        local expected = '/lights/' .. tostring(light.lightId) .. '/state/on'
        for _, item in ipairs(result) do
          if item.success and item.success[expected] == desired then
            finish(t(desired and 'hue.on' or 'hue.off', { name = light.title or t('hue.light') }), 'success')
            return
          end
        end
        finish(t('hue.unconfirmed'))
      end)
    end)
  end, { 'find-generic-password', '-a', config.bridge, '-s', 'hammerspoon.hue', '-w' })
  if not entry.task or not entry.task:start() then
    finish(t('hue.key_access'))
  end
end
return M
