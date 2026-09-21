--- Toggle Discord's visible presence and lunch status using its accessibility controls.
-- @module modules.discord.presence
local M = {}
local notifications = require('modules.notifications')
local job = { id = '', state = 'idle', presence = 'unknown' }
local timer
local defaultMessage = '🥬 Almorzando'
local durations =
  { ['30m'] = '30 minutes', ['1h'] = '1 hour', ['4h'] = '4 hours', ['24h'] = '24 hours', never = "Don't clear" }
local presenceLabels = { online = 'Online', away = 'Idle', dnd = 'Do Not Disturb', invisible = 'Invisible' }
local presenceDurations = {
  ['15m'] = 'For 15 Minutes',
  ['1h'] = 'For 1 Hour',
  ['8h'] = 'For 8 Hours',
  ['24h'] = 'For 24 Hours',
  ['3d'] = 'For 3 Days',
  forever = 'Forever',
}
local bundleID = 'com.hnc.Discord'

local function attr(el, key)
  local ok, value = pcall(el.attributeValue, el, key)
  if ok then
    return value
  end
end

local function name(el)
  local description = attr(el, 'AXDescription')
  local title = attr(el, 'AXTitle')
  local value = attr(el, 'AXValue')
  return description and description ~= '' and description
    or title and title ~= '' and title
    or type(value) == 'string' and value
    or ''
end

-- Skip conversation content: only app controls and the user's profile are relevant.
local function tree(root)
  local queue, result, index = { root }, {}, 1
  while queue[index] and index <= 1800 do
    local el = queue[index]
    index = index + 1
    result[#result + 1] = el
    local label = name(el)
    if
      attr(el, 'AXRole') ~= 'AXMenuBar'
      and not label:match('^Messages in ')
      and not label:match('^Members')
      and label ~= 'Servers sidebar'
    then
      for _, child in ipairs(attr(el, 'AXChildren') or {}) do
        if #queue < 1800 then
          queue[#queue + 1] = child
        end
      end
    end
  end
  return result
end

local function find(elements, label, role)
  for _, el in ipairs(elements) do
    if name(el) == label and (not role or attr(el, 'AXRole') == role) then
      return el
    end
  end
end

local function press(el)
  assert(el and attr(el, 'AXEnabled') ~= false, 'Missing control')
  assert(el:performAction('AXPress'), 'Control did not accept press')
end

local function appTree(app)
  local root = hs.axuielement.applicationElement(app)
  root:setTimeout(0.2)
  -- Electron can leave the accessibility tree incomplete until a client opts in.
  if attr(root, 'AXManualAccessibility') == false then
    pcall(root.setAttributeValue, root, 'AXManualAccessibility', true)
  end
  return tree(root)
end

local function profileButton(elements)
  for _, el in ipairs(elements) do
    if attr(el, 'AXRole') == 'AXButton' and name(el):match('^Your Status: ') then
      return el
    end
  end
end

local function observed(elements)
  local profile = profileButton(elements)
  if profile then
    for key, label in pairs(presenceLabels) do
      local value = name(profile):sub(#'Your Status: ' + 1)
      if value == label or value:sub(1, #label + 1) == label .. ' ' then
        return key
      end
    end
  end
  local panel = find(elements, 'User status and settings')
  if panel then
    for _, el in ipairs(tree(panel)) do
      if attr(el, 'AXRole') == 'AXStaticText' then
        local value = attr(el, 'AXValue') or ''
        for key, label in pairs(presenceLabels) do
          if value == label or value:match('^%S+ ' .. label .. '$') or value:match('^%S+ ' .. label .. '[%s]') then
            return key
          end
        end
      end
    end
  end
  return 'unknown'
end

--- Report ownership of Discord's foreground automation.
function M.isBusy()
  return job.state == 'busy'
end

--- Read current presence without activating Discord or opening menus.
function M.status()
  if job.state ~= 'busy' then
    local app = hs.application.applicationsForBundleID(bundleID)[1]
    local ok, value = pcall(function()
      return app and observed(appTree(app)) or 'unknown'
    end)
    job.presence = ok and value or 'unknown'
  end
  return { id = job.id, state = job.state, presence = job.presence, reason = job.reason or '', phase = job.phase or '' }
end

--- Start an idempotent, focus-checked toggle; poll status for verified completion.
function M.start(id, settings)
  assert(type(id) == 'string' and #id > 0 and #id <= 64 and id:match('^[%w%-]+$'), 'Invalid request ID')
  settings = settings or {}
  local mode = settings.mode or 'lunch'
  local configuredTarget = settings.target or 'away'
  local presenceDuration = settings.presenceDuration or '1h'
  assert(mode == 'lunch' or mode == 'presence', 'Invalid presence mode')
  assert(presenceLabels[configuredTarget], 'Invalid presence target')
  assert(presenceDurations[presenceDuration], 'Invalid presence duration')
  local message = settings.message == nil and defaultMessage or settings.message
  local duration = settings.duration or '1h'
  local emoji = settings.emoji == nil and 'cut_of_meat' or settings.emoji
  assert(type(emoji) == 'string' and #emoji <= 80 and (emoji == '' or emoji:match('^[%w_+%-]+$')), 'Invalid emoji')
  assert(
    type(message) == 'string' and utf8.len(message) and utf8.len(message) <= 128 and not message:find('[%z\1-\31\127]'),
    'Invalid status message'
  )
  assert(durations[duration], 'Invalid status duration')
  if job.state == 'busy' or job.id == id then
    return M.status()
  end
  job = { id = id, state = 'busy', presence = 'unknown' }
  local app = hs.application.applicationsForBundleID(bundleID)[1]
  local function finish(reason)
    if timer then
      timer:stop()
      timer = nil
    end
    job.state, job.reason = reason and 'error' or 'done', reason
    if reason then
      local t = require('modules.i18n').t
      local title = t(mode == 'presence' and 'discord.presence.presence_title' or 'discord.presence.title')
      if reason == 'discord.presence.unconfirmed' then
        notifications.error(
          'discord.presence.step_failed',
          { step = t('discord.presence.step.' .. (job.phase or 'open')) },
          { title = title, final = true }
        )
      else
        notifications.error(reason, nil, { title = title, final = true })
      end
    end
  end
  if not hs.accessibilityState() then
    finish('discord.accessibility')
  elseif not app then
    finish('discord.not_running')
  elseif require('modules.streamdeck').status().state == 'busy' then
    finish('discord.presence.text_busy')
  elseif not app:activate() then
    finish('discord.focus_error')
  else
    local phase, target, expected = 'open', nil, nil
    job.phase = phase
    local started, phaseStarted = hs.timer.secondsSinceEpoch(), hs.timer.secondsSinceEpoch()
    local function advance(nextPhase)
      phase, phaseStarted = nextPhase, hs.timer.secondsSinceEpoch()
      job.phase = phase
    end
    local function step()
      timer = nil
      local front = hs.application.frontmostApplication()
      if not app:isRunning() or not front or front:pid() ~= app:pid() then
        finish('discord.focus_error')
        return
      end
      if hs.timer.secondsSinceEpoch() - started > 45 or hs.timer.secondsSinceEpoch() - phaseStarted > 10 then
        print('[discord.presence] timeout at ' .. phase)
        finish('discord.presence.unconfirmed')
        return
      end
      local ok, err = pcall(function()
        local elements = appTree(app)
        local profile = profileButton(elements)
        if phase == 'open' then
          if find(elements, 'Set your status', 'AXGroup') then
            -- A previous interrupted attempt can leave this dialog open.
            target = observed(elements) == 'away' and 'online' or 'away'
            expected = target == 'away' and message or ''
            press(find(elements, 'Close', 'AXButton'))
            advance('open')
          elseif find(elements, 'Status Actions') then
            local toggle = find(elements, 'Manage profile and status', 'AXButton')
            if toggle then
              press(toggle)
            else
              hs.eventtap.keyStroke({}, 'escape', 0)
            end
          elseif profile then
            advance('choose')
          else
            press(find(elements, 'Manage profile and status', 'AXButton'))
            advance('choose')
          end
        elseif phase == 'choose' and profile then
          target = mode == 'presence' and configuredTarget or (observed(elements) == 'away' and 'online' or 'away')
          expected = target == 'away' and message or ''
          if mode == 'presence' then
            advance('presence')
          elseif target == 'online' then
            local clear = find(elements, 'Clear custom status', 'AXButton')
            if clear then
              press(clear)
            end
            advance('presence')
          else
            local clear = find(elements, 'Clear custom status', 'AXButton')
            if clear then
              press(clear)
            end
            advance('add')
          end
        elseif phase == 'add' then
          local add = find(elements, 'Add custom status', 'AXButton')
          if add then
            press(add)
            advance('edit')
          end
        elseif phase == 'edit' then
          local input = find(elements, 'Status', 'AXTextArea') or find(elements, 'Status', 'AXTextField')
          if input then
            assert(input:setAttributeValue('AXValue', expected), 'Cannot set status')
            advance('text_verify')
          end
        elseif phase == 'text_verify' then
          local input = find(elements, 'Status', 'AXTextArea') or find(elements, 'Status', 'AXTextField')
          if input and attr(input, 'AXValue') == expected then
            if emoji ~= '' and target == 'away' then
              for _, el in ipairs(elements) do
                if attr(el, 'AXRole') == 'AXButton' and name(el):match('^Status emoji:') then
                  press(el)
                  advance('emoji_search')
                  return
                end
              end
              error('Missing emoji button')
            else
              advance('duration_open')
            end
          end
        elseif phase == 'emoji_search' then
          local search = find(elements, 'Search', 'AXComboBox')
          if search then
            assert(search:setAttributeValue('AXValue', emoji), 'Cannot search emoji')
            advance('emoji_select')
          end
        elseif phase == 'emoji_select' then
          for _, el in ipairs(elements) do
            if attr(el, 'AXRole') == 'AXButton' and (name(el) .. ' '):find(':' .. emoji .. ':', 1, true) then
              press(el)
              advance('emoji_verify')
              return
            end
          end
        elseif phase == 'emoji_verify' then
          for _, el in ipairs(elements) do
            if
              attr(el, 'AXRole') == 'AXButton'
              and name(el):match('^Status emoji:')
              and name(el) ~= 'Status emoji: not set'
            then
              job.emojiLabel = name(el):sub(#'Status emoji: ' + 1)
              advance('duration_open')
              return
            end
          end
        elseif phase == 'duration_open' then
          for _, el in ipairs(elements) do
            if name(el):match('^Clear after') and attr(el, 'AXRole') == 'AXPopUpButton' then
              press(el)
              advance('duration')
              return
            end
          end
        elseif phase == 'duration' then
          local option
          for _, el in ipairs(elements) do
            local label = name(el)
            local wanted = durations[duration]
            if
              attr(el, 'AXRole') == 'AXMenuItem' and (label == wanted or label:sub(1, #wanted + 2) == wanted .. ' (')
            then
              option = el
              break
            end
          end
          if option then
            press(option)
            advance('save')
          end
        elseif phase == 'save' then
          local save = find(elements, 'Save', 'AXButton')
          if save then
            press(save)
            advance('reopen')
          end
        elseif phase == 'reopen' then
          if profile then
            advance('presence')
          else
            local open = find(elements, 'Manage profile and status', 'AXButton')
            if open then
              press(open)
              advance('presence')
            end
          end
        elseif phase == 'presence' and profile then
          press(profile)
          advance('select')
        elseif phase == 'select' then
          local menu = find(elements, 'Status Actions')
          if menu then
            local option
            for _, el in ipairs(tree(menu)) do
              local label = name(el)
              local wanted = presenceLabels[target]
              if
                attr(el, 'AXRole') == 'AXMenuItem' and (label == wanted or label:sub(1, #wanted + 1) == wanted .. ' ')
              then
                option = el
                break
              end
            end
            press(option)
            advance(target == 'online' and 'close_before_verify' or 'presence_duration')
          end
        elseif phase == 'presence_duration' then
          local option = find(elements, presenceDurations[presenceDuration], 'AXMenuItem')
          if option then
            press(option)
            advance('close_before_verify')
          end
        elseif phase == 'close_before_verify' then
          -- Discord leaves the duration submenu open even after applying it.
          if profile or find(elements, 'Status Actions') then
            local toggle = find(elements, 'Manage profile and status', 'AXButton')
            if toggle then
              press(toggle)
            else
              -- Electron ignores app-targeted Escape. Foreground was verified above.
              hs.eventtap.keyStroke({}, 'escape', 0)
            end
          else
            advance('verify')
          end
        elseif phase == 'cleanup' then
          if profile or find(elements, 'Status Actions') then
            local toggle = find(elements, 'Manage profile and status', 'AXButton')
            if toggle then
              press(toggle)
            else
              -- Electron ignores app-targeted Escape. Foreground was verified above.
              hs.eventtap.keyStroke({}, 'escape', 0)
            end
          else
            finish()
          end
        elseif phase == 'verify' then
          -- Reopen if Discord closed the profile after selecting a presence.
          if not profile then
            local open = find(elements, 'Manage profile and status', 'AXButton')
            if open then
              press(open)
            end
            return
          end
          local custom = find(elements, 'Your custom status')
          local matches = expected == '' and find(elements, 'Add custom status', 'AXButton') ~= nil
          if custom then
            local hasText = false
            for _, el in ipairs(tree(custom)) do
              if attr(el, 'AXRole') == 'AXStaticText' then
                local value = attr(el, 'AXValue') or ''
                hasText = hasText or value ~= ''
                if value == expected then
                  matches = true
                end
              end
            end
            if expected == '' and not hasText and target == 'away' then
              matches = true
            end
          end
          local emojiMatches = target == 'online' or emoji == ''
          if custom and job.emojiLabel then
            for _, el in ipairs(tree(custom)) do
              if
                attr(el, 'AXRole') == 'AXImage' and (name(el) == ':' .. emoji .. ':' or name(el) == job.emojiLabel)
              then
                emojiMatches = true
              end
            end
          end
          local timed = name(profile):find(' Until ', 1, true) ~= nil
          local durationMatches = target == 'online'
            or (presenceDuration ~= 'forever' and timed)
            or (presenceDuration == 'forever' and not timed)
          if
            observed(elements) == target
            and durationMatches
            and (mode == 'presence' or (matches and emojiMatches))
          then
            job.presence = target
            advance('cleanup')
          end
        end
      end)
      if not ok then
        print('[discord.presence] ' .. phase .. ': ' .. tostring(err))
        finish('discord.presence.unconfirmed')
      elseif job.state == 'busy' then
        timer = hs.timer.doAfter(0.3, step)
      end
    end
    timer = hs.timer.doAfter(0.4, step)
  end
  return M.status()
end
return M
