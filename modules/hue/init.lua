--- Control Hue lights asynchronously using a Bridge key stored in macOS Keychain.
-- @module modules.hue.init

local t = require('modules.i18n').t
-- Hue local API v1. Credentials stay in Keychain, never in action metadata.
local notifications = require('modules.notifications')
local M = {}
-- Entries serialize operations per bridge/light pair and invalidate late callbacks.
local pending = {}
local states, listeners, observed = {}, {}, {}
local function identity(config, light)
  return tostring(config.bridge) .. '/' .. tostring(light.lightId)
end
local function publish(id, state)
  states[id] = state
  for listener in pairs(listeners) do
    pcall(listener)
  end
end

--- Return only public display state; credentials never leave this module.
function M.state(config, light)
  return states[identity(config, light)] or 'unknown'
end

--- Return the last observed light data for local preset matching.
function M.details(config, light)
  return observed[identity(config, light)]
end

--- Subscribe to state changes and return an unsubscribe function.
function M.subscribe(listener)
  listeners[listener] = true
  return function()
    listeners[listener] = nil
  end
end
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
-- @param light Light metadata with lightId and a power, preset or brightness action.
-- Writes notify on completion; background reads publish state silently.
local function perform(config, light, readOnly)
  if not validBridge(config.bridge) or not tostring(light.lightId):match('^%d+$') then
    if not readOnly then
      notifications.warning('hue.config')
    end
    return
  end
  local operation = light.action or 'toggle'
  if
    not readOnly
    and operation ~= 'toggle'
    and operation ~= 'on'
    and operation ~= 'off'
    and operation ~= 'preset'
    and operation ~= 'brightness'
  then
    notifications.warning('hue.action')
    return
  end
  local id = identity(config, light)
  if pending[id] then
    if readOnly then
      return
    end
    if not pending[id].readOnly then
      notifications.info('hue.busy')
      return
    end
    -- A user command supersedes a background read; stale callbacks are ignored.
    if pending[id].timer then
      pending[id].timer:stop()
    end
  end
  local entry = { readOnly = readOnly }
  pending[id] = entry
  -- Completion and timeout share cleanup so a late response cannot notify twice.
  local function finish(message, level, state, data)
    if pending[id] ~= entry then
      return
    end
    pending[id] = nil
    if entry.timer then
      entry.timer:stop()
    end
    if entry.settle then
      entry.settle:stop()
    end
    observed[id] = data
    publish(id, state or 'unknown')
    if not readOnly and message then
      notifications.text(level or 'error', message)
    end
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
  if not readOnly or not states[id] then
    observed[id] = nil
    publish(id, 'loading')
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
        finish(t('hue.unreachable'), 'error', 'unreachable')
        return
      end
      if readOnly then
        finish(nil, nil, data.state.on and 'on' or 'off', data)
        return
      end
      local extended = operation == 'preset' or operation == 'brightness'
      local desired = operation == 'on' or (operation == 'toggle' and not data.state.on)
      local body = { on = desired }
      if extended then
        local errorKey
        body, errorKey = require('modules.hue.presets').payload(config, light, data)
        if not body then
          finish(t(errorKey))
          return
        end
      end
      request('PUT', url .. '/state', hs.json.encode(body), function(result)
        local confirmed = {}
        for _, item in ipairs(result) do
          for path, value in pairs(item.success or {}) do
            confirmed[path] = value
          end
        end
        for field, value in pairs(body) do
          if
            field ~= 'transitiontime'
            and confirmed['/lights/' .. tostring(light.lightId) .. '/state/' .. field] ~= value
          then
            finish(t('hue.unconfirmed'))
            return
          end
        end
        if not extended then
          data.state.on = desired
          finish(
            t(desired and 'hue.on' or 'hue.off', { name = light.title or t('hue.light') }),
            'success',
            desired and 'on' or 'off',
            data
          )
          return
        end
        -- Read back after the transition instead of presenting a requested color as observed.
        entry.settle = hs.timer.doAfter(body.transitiontime / 10 + 0.2, function()
          if pending[id] ~= entry then
            return
          end
          request('GET', url, nil, function(actual)
            if type(actual.state) ~= 'table' or type(actual.state.on) ~= 'boolean' then
              finish(t('hue.unknown'))
              return
            end
            if actual.state.reachable == false then
              finish(t('hue.unreachable'), 'error', 'unreachable')
              return
            end
            finish(
              t('hue.updated', { name = light.title or t('hue.light') }),
              'success',
              actual.state.on and 'on' or 'off',
              actual
            )
          end)
        end)
      end)
    end)
  end, { 'find-generic-password', '-a', config.bridge, '-s', 'hammerspoon.hue', '-w' })
  if not entry.task or not entry.task:start() then
    finish(t('hue.key_access'))
  end
end

--- Read Bridge state silently; this never sends a light-changing request.
function M.refresh(config, light)
  perform(config, light, true)
end

--- Execute the configured operation and publish only confirmed state.
function M.run(config, light)
  perform(config, light, false)
end
return M
