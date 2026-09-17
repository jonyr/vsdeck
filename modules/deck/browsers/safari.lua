local M = {}
local timer, busy

local function finish(errorMessage)
  if timer then timer:stop(); timer = nil end
  busy = false
  if errorMessage then
    hs.notify.new({ title = 'Deck · Safari', informativeText = errorMessage }):send()
  end
end

local validate = require('modules.deck.web_validation').validate

local function openTabs(app, window, urls, index)
  if not app:isFrontmost() or app:focusedWindow() ~= window then
    finish('Cambió la ventana activa. Se detuvo la apertura de pestañas.'); return
  end
  if index > #urls then finish(); return end
  if index > 1 then hs.eventtap.keyStroke({ 'cmd' }, 't', 0, app) end
  timer = hs.timer.doAfter(0.25, function()
    if not app:isFrontmost() or app:focusedWindow() ~= window then
      finish('Cambió la ventana activa. Se detuvo la apertura de pestañas.'); return
    end
    hs.eventtap.keyStroke({ 'cmd' }, 'l', 0, app)
    timer = hs.timer.doAfter(0.2, function()
      if not app:isFrontmost() or app:focusedWindow() ~= window then
        finish('Cambió la ventana activa. Se detuvo la apertura de pestañas.'); return
      end
      hs.eventtap.keyStrokes(urls[index], app)
      hs.eventtap.keyStroke({}, 'return', 0, app)
      timer = hs.timer.doAfter(0.3, function() openTabs(app, window, urls, index + 1) end)
    end)
  end)
end

-- Returns true when accepted, or false + an error. Runs asynchronously.
-- Profile names must match Safari exactly; menu labels support English/Spanish.
function M.openProfile(profile, urls)
  if busy then return false, 'Safari ya está abriendo un grupo de pestañas.' end
  local list, err = validate(profile, urls)
  if not list then return false, err end
  busy = true
  if not hs.application.launchOrFocusByBundleID('com.apple.Safari') then
    finish('No se pudo abrir Safari.'); return false, 'No se pudo abrir Safari.'
  end
  local attempts, requested, previous = 0, false, {}
  timer = hs.timer.doEvery(0.2, function()
    attempts = attempts + 1
    if attempts > 50 then finish('No se pudo abrir el perfil ' .. profile .. '. Comprueba su nombre y el menú de Safari.'); return end
    local app = hs.application.get('com.apple.Safari')
    if not app or not app:isFrontmost() then return end
    if not requested then
      local menu
      for _, candidate in ipairs({
        { 'File', 'New Window', 'New ' .. profile .. ' Window' },
        { 'Archivo', 'Nueva ventana', 'Nueva ventana de ' .. profile },
      }) do
        local item = app:findMenuItem(candidate)
        if item and item.enabled then menu = candidate; break end
      end
      if not menu then return end
      for _, window in ipairs(app:allWindows()) do previous[window:id()] = true end
      if not app:selectMenuItem(menu) then finish('No se pudo seleccionar el perfil ' .. profile .. '.'); return end
      requested = true
      return
    end
    local window = app:focusedWindow()
    if not window or previous[window:id()] then return end
    local title = window:title()
    if title ~= profile and title:sub(1, #profile + 4) ~= profile .. ' —' then return end
    -- Only type into the new, focused profile window; never reuse another profile.
    timer:stop()
    openTabs(app, window, list, 1)
  end)
  return true
end

-- Common adapter contract: open(request, spec) -> accepted, error.
function M.open(request, spec)
  if request.profile then return M.openProfile(request.profile, request.urls) end
  if busy then return false, 'Safari ya está abriendo un grupo de pestañas.' end
  local args = { '-b', spec.bundle }
  for _, url in ipairs(request.urls) do args[#args + 1] = url end
  return require('modules.deck.browsers.process').launch('/usr/bin/open', args)
end

return M
