package.path = './?.lua;./?/init.lua;' .. package.path
local pending, clock, notices, writes = {}, 0, {}, 0
local view, presence, custom, duration = 'main', 'Online', '', nil
local focused, running, permission, failSave, missingMenu = true, true, true, false, false
local textBusy = false
local modalOnly = false
local presenceDuration, durationMissing, suffix = nil, false, ''
local draft, selectedEmoji, searchEmoji = '', '', ''
local function element(label, role, children, onPress, value)
  local attributes = {
    AXDescription = label,
    AXRole = role or 'AXButton',
    AXChildren = children or {},
    AXValue = value or '',
    AXEnabled = true,
  }
  return {
    attributeValue = function(_, key)
      return attributes[key]
    end,
    setAttributeValue = function(_, key, val)
      -- Discord acknowledges the write before its AXValue is refreshed.
      -- Keep this element stale; the next tree exposes the committed value.
      if role == 'AXTextArea' then
        draft = val
        writes = writes + 1
      elseif role == 'AXComboBox' then
        searchEmoji = val
        view = 'emoji_results'
      else
        attributes[key] = val
      end
      return true
    end,
    performAction = function()
      if onPress then
        onPress()
      end
      return true
    end,
    setTimeout = function() end,
  }
end
local function text(value)
  return element('', 'AXStaticText', nil, nil, value)
end
local function profile()
  local result = { element('Your Status: ' .. presence .. suffix, 'AXButton', nil, function()
    view = 'menu'
  end) }
  if custom == '' then
    result[#result + 1] = element('Add custom status', 'AXButton', nil, function()
      view = 'edit'
    end)
  else
    result[#result + 1] =
      element('Your custom status', 'AXGroup', { text(custom), element(':' .. selectedEmoji .. ':', 'AXImage') })
    result[#result + 1] = element('Edit custom status', 'AXPopUpButton', nil, function()
      view = 'edit'
    end)
    result[#result + 1] = element('Clear custom status', 'AXButton', nil, function()
      custom = ''
      selectedEmoji = ''
      draft = ''
    end)
  end
  return result
end
local function root()
  local children = {
    element('User status and settings', 'AXGroup', { text('user ' .. presence .. ' ' .. custom) }),
    element('Manage profile and status', 'AXButton', nil, function()
      view = view == 'main' and 'profile' or 'main'
    end),
  }
  if modalOnly and view == 'profile' then
    table.remove(children, 2)
  end
  if view == 'profile' or view == 'menu' or view == 'presence_duration' then
    for _, el in ipairs(profile()) do
      children[#children + 1] = el
    end
  end
  if view == 'edit' then
    children[#children + 1] = element(
      'Status emoji: ' .. (selectedEmoji == '' and 'not set' or '🥩'),
      'AXButton',
      nil,
      function()
        view = 'emoji_search'
      end
    )
    children[#children + 1] = element('Status', 'AXTextArea', nil, nil, draft)
    children[#children + 1] = element('Clear after, tomorrow', 'AXPopUpButton', nil, function()
      view = 'duration'
    end)
    children[#children + 1] = element('Save', 'AXButton', nil, function()
      if not failSave then
        custom = draft
      end
      view = 'main'
    end)
  elseif view == 'emoji_search' then
    children[#children + 1] = element('Search', 'AXComboBox')
  elseif view == 'emoji_results' then
    if searchEmoji ~= 'does_not_exist' then
      children[#children + 1] = element(':' .. searchEmoji .. ':', 'AXButton', nil, function()
        selectedEmoji = searchEmoji
        view = 'edit'
      end)
    end
  elseif view == 'duration' then
    for _, option in ipairs({
      { '30 minutes', 1800 },
      { '1 hour', 3600 },
      { '4 hours', 14400 },
      { '24 hours', 86400 },
      { "Don't clear", 0 },
    }) do
      children[#children + 1] = element('', 'AXMenuItem', nil, function()
        duration = option[2]
        view = 'save'
      end, option[1] .. (option[2] == 0 and '' or ' (6:00 PM)'))
    end
  elseif view == 'save' then
    children[#children + 1] = element('Save', 'AXButton', nil, function()
      if not failSave then
        custom = draft
      end
      view = 'main'
    end)
  elseif view == 'menu' and not missingMenu then
    local options = {}
    for _, label in ipairs({ 'Idle', 'Online', 'Do Not Disturb', 'Invisible' }) do
      options[#options + 1] = element('', 'AXMenuItem', nil, function()
        presence = label
        suffix = ''
        view = label == 'Online' and 'profile' or 'presence_duration'
      end, label .. (label == 'Do Not Disturb' and ' You will not receive desktop notifications' or ''))
    end
    children[#children + 1] = element('Status Actions', 'AXGroup', options)
  elseif view == 'presence_duration' and not durationMissing then
    for _, label in ipairs({ 'For 15 Minutes', 'For 1 Hour', 'For 8 Hours', 'For 24 Hours', 'For 3 Days', 'Forever' }) do
      children[#children + 1] = element(label, 'AXMenuItem', nil, function()
        presenceDuration = label
        suffix = label == 'Forever' and '' or ' Until 6:00 PM'
        -- Real Discord leaves the menus visible after applying the duration.
      end)
    end
  end
  return element('', 'AXApplication', children)
end
local app = {
  pid = function()
    return 1
  end,
  isRunning = function()
    return running
  end,
  activate = function()
    return true
  end,
}
hs = {
  application = {
    applicationsForBundleID = function()
      return running and { app } or {}
    end,
    frontmostApplication = function()
      return focused and app or nil
    end,
  },
  accessibilityState = function()
    return permission
  end,
  axuielement = { applicationElement = root },
  eventtap = {
    keyStroke = function()
      view = 'main'
    end,
  },
  timer = {
    secondsSinceEpoch = function()
      return clock
    end,
    doAfter = function(delay, callback)
      local timer = {
        stopped = false,
        stop = function(self)
          self.stopped = true
        end,
      }
      pending[#pending + 1] = { delay = delay, callback = callback, timer = timer }
      return timer
    end,
  },
}
package.loaded['modules.notifications'] = {
  error = function(key)
    notices[#notices + 1] = key
  end,
}
package.loaded['modules.i18n'] = {
  t = function(key)
    return key
  end,
}
package.loaded['modules.streamdeck'] = {
  status = function()
    return { state = textBusy and 'busy' or 'idle' }
  end,
}
local m = require('modules.discord.presence')
local function drain()
  for _ = 1, 120 do
    local item = table.remove(pending, 1)
    if not item then
      return
    end
    clock = clock + item.delay
    if not item.timer.stopped then
      item.callback()
    end
  end
  error('Unbounded automation')
end
assert(m.status().presence == 'online')
assert(m.start('one').state == 'busy')
assert(m.start('two').id == 'one')
drain()
assert(m.status().state == 'done' and m.status().presence == 'away')
assert(view == 'main' and presenceDuration == 'For 1 Hour')
assert(custom == '🥬 Almorzando' and selectedEmoji == 'cut_of_meat' and duration == 3600)
local previousWrites = writes
assert(m.start('one').state == 'done' and writes == previousWrites)
m.start('return')
drain()
assert(m.status().state == 'done' and presence == 'Online' and custom == '')
-- External presence changes must be observed, not inferred from our last click.
presence = 'Idle'
assert(m.status().presence == 'away')
presence = 'Do Not Disturb'
assert(m.status().presence == 'dnd')
presence = 'Online'
focused = false
m.start('focus')
drain()
assert(m.status().reason == 'discord.focus_error' and custom == '')
focused = true
failSave = true
m.start('save-failure')
drain()
assert(m.status().state == 'error')
assert(m.status().reason == 'discord.presence.unconfirmed')
failSave = false
missingMenu = true
presence = 'Online'
view = 'main'
m.start('menu-failure')
drain()
assert(m.status().state == 'error')
missingMenu = false
running = false
m.start('closed')
assert(m.status().reason == 'discord.not_running')
running = true
permission = false
m.start('permission')
assert(m.status().reason == 'discord.accessibility')
permission = true
textBusy = true
m.start('text-busy')
assert(m.status().reason == 'discord.presence.text_busy')
assert(#notices == 6)
print('Discord presence tests passed')

-- Every supported duration, empty emoji, arbitrary quotes, and stale AX reads.
textBusy = false
for key, seconds in pairs({ ['30m'] = 1800, ['1h'] = 3600, ['4h'] = 14400, ['24h'] = 86400, never = 0 }) do
  presence = 'Online'
  view = 'main'
  custom = ''
  selectedEmoji = ''
  draft = ''
  m.start('duration-' .. key, { message = 'I\'m away "quoted"', emoji = '', duration = key })
  drain()
  assert(m.status().state == 'done', m.status().phase)
  assert(duration == seconds and custom == 'I\'m away "quoted"' and selectedEmoji == '')
end
presence = 'Online'
view = 'main'
custom = ''
selectedEmoji = ''
draft = ''
m.start('missing-emoji', { message = 'Lunch', emoji = 'does_not_exist', duration = '30m' })
drain()
assert(m.status().state == 'error' and m.status().phase == 'emoji_select')
assert(not pcall(m.start, 'bad-duration', { duration = '2h' }))
assert(not pcall(m.start, 'bad-message', { message = string.rep('x', 129) }))
assert(not pcall(m.start, 'bad-control', { message = 'line\nline' }))
print('Discord custom settings and delayed AX verification passed')

-- Presence-only actions preserve custom status and select every native duration.
modalOnly = true
for key, label in pairs({ online = 'Online', away = 'Idle', dnd = 'Do Not Disturb', invisible = 'Invisible' }) do
  for durationKey, durationLabel in pairs({
    ['15m'] = 'For 15 Minutes',
    ['1h'] = 'For 1 Hour',
    ['8h'] = 'For 8 Hours',
    ['24h'] = 'For 24 Hours',
    ['3d'] = 'For 3 Days',
    forever = 'Forever',
  }) do
    view = 'main'
    custom = 'Keep this'
    selectedEmoji = 'coffee'
    presenceDuration = nil
    m.start(
      'presence-' .. key .. '-' .. durationKey,
      { mode = 'presence', target = key, presenceDuration = durationKey }
    )
    drain()
    assert(m.status().state == 'done', m.status().phase)
    assert(presence == label and custom == 'Keep this' and selectedEmoji == 'coffee' and view == 'main')
    assert(key == 'online' and presenceDuration == nil or presenceDuration == durationLabel)
  end
end
view = 'main'
durationMissing = true
m.start('missing-presence-duration', { mode = 'presence', target = 'away' })
drain()
assert(m.status().state == 'error' and m.status().phase == 'presence_duration')
assert(not pcall(m.start, 'bad-target', { target = 'bogus' }))
assert(not pcall(m.start, 'bad-presence-duration', { presenceDuration = '30m' }))
print('Discord presence targets, native durations, status preservation and menu cleanup passed')
