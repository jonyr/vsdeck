--- Open Safari profile windows through native menus with guarded focus transitions.
-- @module modules.deck.browsers.safari

local t = require('modules.i18n').t
local M = {}
local timer, busy

-- Every exit path clears the timer and busy guard before reporting an error.
local function finish(errorMessage)
  if timer then
    timer:stop()
    timer = nil
  end
  busy = false
  if errorMessage then
    require('modules.notifications').text('error', errorMessage)
  end
end

local validate = require('modules.deck.web_validation').validate

-- Recheck focus before each delayed keystroke to avoid typing into another application.
local function openTabs(app, window, urls, index)
  if not app:isFrontmost() or app:focusedWindow() ~= window then
    finish(t('safari.focus_changed'))
    return
  end
  if index > #urls then
    finish()
    return
  end
  if index > 1 then
    hs.eventtap.keyStroke({ 'cmd' }, 't', 0, app)
  end
  timer = hs.timer.doAfter(0.25, function()
    if not app:isFrontmost() or app:focusedWindow() ~= window then
      finish(t('safari.focus_changed'))
      return
    end
    hs.eventtap.keyStroke({ 'cmd' }, 'l', 0, app)
    timer = hs.timer.doAfter(0.2, function()
      if not app:isFrontmost() or app:focusedWindow() ~= window then
        finish(t('safari.focus_changed'))
        return
      end
      hs.eventtap.keyStrokes(urls[index], app)
      hs.eventtap.keyStroke({}, 'return', 0, app)
      timer = hs.timer.doAfter(0.3, function()
        openTabs(app, window, urls, index + 1)
      end)
    end)
  end)
end

-- Returns true when accepted, or false + an error. Runs asynchronously.
-- Profile names must match Safari exactly; menu labels support English/Spanish.
--- Start one serialized profile-opening sequence.
-- @param profile Exact Safari profile name.
-- @param urls Ordered HTTP(S) URLs, copied before scheduling work.
-- @return true when accepted, or false plus an immediate error message.
function M.openProfile(profile, urls)
  if busy then
    return false, t('safari.busy')
  end
  local list, err = validate(profile, urls)
  if not list then
    return false, err
  end
  busy = true
  if not hs.application.launchOrFocusByBundleID('com.apple.Safari') then
    finish(t('safari.open_error'))
    return false, t('safari.open_error')
  end
  local attempts, requested, previous = 0, false, {}
  timer = hs.timer.doEvery(0.2, function()
    attempts = attempts + 1
    if attempts > 50 then
      finish(t('safari.profile_error', { profile = profile }))
      return
    end
    local app = hs.application.get('com.apple.Safari')
    if not app or not app:isFrontmost() then
      return
    end
    if not requested then
      local menu
      -- These are native Safari menu labels, not UI translations controlled by VSDeck.
      for _, candidate in ipairs({
        { 'File', 'New Window', 'New ' .. profile .. ' Window' },
        { 'Archivo', 'Nueva ventana', 'Nueva ventana de ' .. profile },
      }) do
        local item = app:findMenuItem(candidate)
        if item and item.enabled then
          menu = candidate
          break
        end
      end
      if not menu then
        return
      end
      for _, window in ipairs(app:allWindows()) do
        previous[window:id()] = true
      end
      if not app:selectMenuItem(menu) then
        finish(t('safari.select_error', { profile = profile }))
        return
      end
      requested = true
      return
    end
    local window = app:focusedWindow()
    if not window or previous[window:id()] then
      return
    end
    local title = window:title()
    if title ~= profile and title:sub(1, #profile + 4) ~= profile .. ' —' then
      return
    end
    -- Only type into the new, focused profile window; never reuse another profile.
    timer:stop()
    openTabs(app, window, list, 1)
  end)
  return true
end

-- Common adapter contract: open(request, spec) -> accepted, error.
--- Open an explicit Safari profile or delegate default browsing to macOS.
-- @param request Validated shortcut with optional profile and ordered URLs.
-- @param spec Registry entry containing Safari bundle metadata.
-- @return true when accepted, or false plus an error message.
function M.open(request, spec)
  if request.profile then
    return M.openProfile(request.profile, request.urls)
  end
  if busy then
    return false, t('safari.busy')
  end
  local args = { '-b', spec.bundle }
  for _, url in ipairs(request.urls) do
    args[#args + 1] = url
  end
  return require('modules.deck.browsers.process').launch('/usr/bin/open', args)
end

return M
