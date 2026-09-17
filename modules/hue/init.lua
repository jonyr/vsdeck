-- Hue local API v1. Credentials stay in Keychain, never in action metadata.
local M = {}
local pending = {}
local function validBridge(value)
  if type(value) ~= 'string' then return false end
  local count = 0
  for part in value:gmatch('[^.]+') do
    if not part:match('^%d+$') or tonumber(part) > 255 then return false end
    count = count + 1
  end
  return count == 4 and value:match('^%d+%.%d+%.%d+%.%d+$') ~= nil
end

function M.run(config, light)
  if not validBridge(config.bridge) or not tostring(light.lightId):match('^%d+$') then
    hs.alert.show('Hue: configura la IP del Bridge y el ID de la luz.'); return
  end
  local operation = light.action or 'toggle'
  if operation ~= 'toggle' and operation ~= 'on' and operation ~= 'off' then
    hs.alert.show('Hue: acción inválida (toggle, on u off).'); return
  end
  local id = config.bridge .. '/' .. tostring(light.lightId)
  if pending[id] then hs.alert.show('Hue: operación en curso.'); return end
  local entry = {}
  pending[id] = entry
  local function finish(message)
    if pending[id] ~= entry then return end
    pending[id] = nil
    if entry.timer then entry.timer:stop() end
    hs.alert.show(message, 4)
  end
  local function request(method, url, body, callback)
    hs.http.doAsyncRequest(url, method, body, {['Content-Type']='application/json'}, function(status, raw)
      if pending[id] ~= entry then return end
      if status ~= 200 then finish('Hue: no se pudo contactar al Bridge.'); return end
      local ok, data = pcall(hs.json.decode, raw)
      if not ok or type(data) ~= 'table' then finish('Hue: respuesta inválida.'); return end
      for _, item in ipairs(data) do
        if item.error then finish('Hue: el Bridge rechazó la operación. Revisa la vinculación.'); return end
      end
      callback(data)
    end)
  end
  entry.timer = hs.timer.doAfter(20, function() finish('Hue: se agotó el tiempo de espera. Comprueba el estado de la luz.'); end)
  entry.task = hs.task.new('/usr/bin/security', function(code, stdout)
    if pending[id] ~= entry then return end
    local key = (stdout or ''):gsub('%s+$', '')
    if code ~= 0 or not key:match('^[%w%-]+$') then
      finish('Hue: no se pudo leer la clave del llavero.'); return
    end
    local url = 'http://' .. config.bridge .. '/api/' .. key .. '/lights/' .. tostring(light.lightId)
    request('GET', url, nil, function(data)
      if not data.state or type(data.state.on) ~= 'boolean' then finish('Hue: luz desconocida.'); return end
      if data.state.reachable == false then finish('Hue: la luz no está accesible. Revisa su alimentación.'); return end
      local desired = operation == 'on' or (operation == 'toggle' and not data.state.on)
      request('PUT', url .. '/state', hs.json.encode({on=desired}), function(result)
        local expected = '/lights/' .. tostring(light.lightId) .. '/state/on'
        for _, item in ipairs(result) do
          if item.success and item.success[expected] == desired then
            finish((light.title or 'Luz') .. (desired and ': encendida' or ': apagada')); return
          end
        end
        finish('Hue: el Bridge no confirmó el cambio.')
      end)
    end)
  end, {'find-generic-password', '-a', config.bridge, '-s', 'hammerspoon.hue', '-w'})
  if not entry.task or not entry.task:start() then finish('Hue: no se pudo acceder al llavero.') end
end
return M
