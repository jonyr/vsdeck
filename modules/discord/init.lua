--- Send Discord's official voice toggles to its desktop app, never the current editor.
-- @module modules.discord
local M = {}
local status = require('modules.discord.status')
local timer
local keys = { mute = 'm', deafen = 'd' }
local bundleID = 'com.hnc.Discord'

--- Schedule one toggle after Discord gains focus; never retry an uncertain toggle.
-- @return true when scheduled, false when rejected; delivery does not confirm voice state.
function M.run(action)
  local key = keys[action]
  if not key or timer then
    return false
  end
  local notify = require('modules.notifications')
  if not hs.accessibilityState() then
    notify.warning('discord.accessibility')
    return false
  end
  local app = hs.application.applicationsForBundleID(bundleID)[1]
  if not app then
    notify.warning('discord.not_running')
    return false
  end
  if not app:activate() then
    notify.error('discord.focus_error')
    return false
  end
  timer = hs.timer.doAfter(0.25, function()
    timer = nil
    local front = hs.application.frontmostApplication()
    if not front or front:pid() ~= app:pid() or not app:isRunning() then
      notify.error('discord.focus_error')
      return
    end
    if hs.eventtap.isSecureInputEnabled() then
      notify.warning('discord.secure_input')
      return
    end
    -- Target the validated process explicitly; a second toggle could undo the first.
    local ok = pcall(hs.eventtap.keyStroke, { 'cmd', 'shift' }, key, 0, app)
    if not ok then
      notify.error('discord.send_error')
      return
    end
    timer = hs.timer.doAfter(0.4, function()
      timer = nil
      status.refresh()
    end)
  end)
  return true
end

--- Release a scheduled shortcut when explicitly unloading the module.
function M.stop()
  status.stop()
  if timer then
    timer:stop()
    timer = nil
  end
end

--- Build the same two source-independent actions for HTML and Canvas.
function M.actions()
  local t = require('modules.i18n').t
  local result = {}
  for _, item in ipairs({ { 'mute', '🎙️' }, { 'deafen', '🎧' } }) do
    local action = item[1]
    result[#result + 1] = {
      id = 'discord.' .. action,
      title = t('discord.' .. action .. '.title'),
      subtitle = t('discord.' .. action .. '.subtitle'),
      badge = item[2],
      category = 'Discord',
      requiresOrigin = false,
      keywords = 'discord mute unmute deafen undeafen microfono audio',
      statusKey = 'discord.voice',
      statusSource = 'discord',
      subscribeStatus = status.subscribe,
      refreshStatus = status.refresh,
      getStatus = function()
        return status.state(action)
      end,
      getPresentation = function()
        local state = status.state(action)
        return { label = t('discord.state.' .. state), active = state == 'muted' or state == 'deafened' }
      end,
      run = function()
        M.run(action)
      end,
    }
  end
  return result
end
return M
