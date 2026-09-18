--- Observe Discord voice controls without sending shortcuts or opening its window.
-- @module modules.discord.status
local M = {}
local states = { mute = 'unknown', deafen = 'unknown' }
local listeners, controls = {}, {}
local scanTimer, processID
-- Labels identify controls only: Discord can keep them unchanged while muted.
local labels = {
  Mute = 'mute',
  Unmute = 'mute',
  Deafen = 'deafen',
  Undeafen = 'deafen',
}

local function attribute(element, name)
  local ok, value = pcall(element.attributeValue, element, name)
  if ok then
    return value
  end
end

local function identify(element)
  local role = attribute(element, 'AXRole')
  if role ~= 'AXCheckBox' and role ~= 'AXSwitch' then
    return
  end
  return labels[attribute(element, 'AXDescription')]
end

local function read(element)
  local action = identify(element)
  if not action or attribute(element, 'AXEnabled') == false then
    return 'unknown'
  end
  local value = attribute(element, 'AXValue')
  -- Only explicit switch values convey state. Names, nearby tooltips, CSS classes
  -- and AXSelected do not establish whether this voice control is checked.
  local active
  if value == true or value == 1 or value == '1' then
    active = true
  elseif value == false or value == 0 or value == '0' then
    active = false
  else
    return 'unknown'
  end
  if active then
    return action == 'mute' and 'muted' or 'deafened'
  end
  return action == 'mute' and 'unmuted' or 'listening'
end

local function publish(mute, deafen)
  states = { mute = mute, deafen = deafen }
  for callback in pairs(listeners) do
    pcall(callback)
  end
end

--- Return only the most recently observed state, never a predicted toggle result.
function M.state(action)
  return states[action] or 'unknown'
end

--- Cancel discovery and clear cached accessibility objects.
function M.stop()
  if scanTimer then
    scanTimer:stop()
    scanTimer = nil
  end
  controls, processID = {}, nil
  states = { mute = 'unknown', deafen = 'unknown' }
end

--- Subscribe while a Deck is visible; the last subscriber releases discovery.
function M.subscribe(callback)
  listeners[callback] = true
  return function()
    listeners[callback] = nil
    if not next(listeners) then
      M.stop()
    end
  end
end

--- Refresh cached controls or discover them in bounded batches on the main loop.
function M.refresh()
  if scanTimer then
    return
  end
  if not hs.accessibilityState() then
    controls = {}
    publish('permission', 'permission')
    return
  end
  local app = hs.application.applicationsForBundleID('com.hnc.Discord')[1]
  if not app then
    controls = {}
    publish('closed', 'closed')
    return
  end
  if processID ~= app:pid() then
    controls = {}
    processID = app:pid()
  end
  if controls.mute and controls.deafen then
    local mute, deafen = identify(controls.mute), identify(controls.deafen)
    if mute and mute == 'mute' and deafen and deafen == 'deafen' then
      publish(read(controls.mute), read(controls.deafen))
      return
    end
  end
  controls = {}
  publish('unknown', 'unknown')
  local ok, root = pcall(hs.axuielement.applicationElement, app)
  if not ok or not root then
    return
  end
  root:setTimeout(0.05)
  local queue, index = { root }, 1
  local deadline = hs.timer.secondsSinceEpoch() + 3
  local function step()
    scanTimer = nil
    if not app:isRunning() then
      controls = {}
      publish('closed', 'closed')
      return
    end
    for _ = 1, 40 do
      local element = queue[index]
      if not element or index > 3000 or hs.timer.secondsSinceEpoch() > deadline then
        publish(
          controls.mute and read(controls.mute) or 'unknown',
          controls.deafen and read(controls.deafen) or 'unknown'
        )
        return
      end
      index = index + 1
      local label = identify(element)
      if label then
        controls[label] = element
      end
      if controls.mute and controls.deafen then
        publish(read(controls.mute), read(controls.deafen))
        return
      end
      for _, child in ipairs(attribute(element, 'AXChildren') or {}) do
        if #queue < 3000 then
          queue[#queue + 1] = child
        end
      end
    end
    scanTimer = hs.timer.doAfter(0.01, step)
  end
  scanTimer = hs.timer.doAfter(0, step)
end
return M
