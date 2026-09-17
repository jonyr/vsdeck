--- Discover local clips and own one sound at a time across both Deck interfaces.
-- @module modules.soundboard

local M = {}
local current
local extensions = { mp3 = true, wav = true, aiff = true, aif = true, m4a = true, caf = true }

local function expand(path)
  return (path:gsub('^~/', function()
    return os.getenv('HOME') .. '/'
  end))
end

--- Resolve the configurable audio directory without reading personal files directly.
function M.directory(config)
  return expand(config.directory or ((hs.configdir or '.') .. '/sounds'))
end

--- Return a stable, alphabetically sorted catalog; scanning never plays audio.
-- @param config Soundboard settings; sounds optionally replaces directory discovery.
function M.clips(config)
  if config.sounds then
    return config.sounds
  end
  local directory = M.directory(config)
  local clips = {}
  if not hs.fs or hs.fs.attributes(directory, 'mode') ~= 'directory' then
    return clips
  end
  local ok = pcall(function()
    for name in hs.fs.dir(directory) do
      local extension = name:match('%.([^%.]+)$')
      local path = directory .. '/' .. name
      if extension and extensions[extension:lower()] and hs.fs.attributes(path, 'mode') == 'file' then
        clips[#clips + 1] = { id = name, title = name:gsub('%.[^%.]+$', ''), path = path }
      end
    end
  end)
  if not ok then
    return {}
  end
  table.sort(clips, function(a, b)
    return a.id < b.id
  end)
  return clips
end

--- Stop the retained sound; completion of an older clip cannot clear a newer one.
function M.stop()
  local previous = current
  current = nil
  if previous then
    previous:setCallback(nil)
    previous:stop()
  end
end

--- Play a local clip from the beginning, replacing the previous sound only after loading.
-- @return true if playback started, false after a localized error notification.
function M.play(clip, config)
  local notify = require('modules.notifications')
  local title = clip.title or clip.id or ''
  local path = type(clip.path) == 'string' and expand(clip.path) or ''
  local ok, sound = pcall(hs.sound.getByFile, path)
  if not ok or not sound then
    notify.error('soundboard.load_error', { title = title })
    return false
  end
  local volume = tonumber(clip.volume or config.volume) or 0.5
  if volume ~= volume then
    volume = 0.5
  end
  sound:volume(math.max(0, math.min(1, volume)))
  sound:loopSound(false)
  sound:device(nil)
  M.stop()
  current = sound -- Keep the userdata alive until completion or explicit stop.
  sound:setCallback(function(success)
    if current ~= sound then
      return
    end
    current = nil
    if not success then
      notify.error('soundboard.play_error', { title = title })
    end
  end)
  if not sound:play() then
    M.stop()
    notify.error('soundboard.play_error', { title = title })
    return false
  end
  return true
end

--- Build actions lazily so opening the Deck never starts playback or takes focus.
function M.actions(config)
  if config.enabled == false then
    return {}
  end
  local t = require('modules.i18n').t
  local actions = {
    {
      id = 'soundboard.stop',
      title = t('soundboard.stop'),
      badge = '■',
      subtitle = t('soundboard.stop_hint'),
      run = M.stop,
    },
    {
      id = 'soundboard.library',
      title = t('soundboard.library'),
      badge = '♫',
      subtitle = t('soundboard.library_hint'),
      run = function()
        hs.urlevent.openURL('https://tuna.voicemod.net/sounds/')
      end,
    },
  }
  for _, clip in ipairs(M.clips(config)) do
    actions[#actions + 1] = {
      id = 'soundboard.clip.' .. clip.id,
      title = clip.title or clip.id,
      badge = clip.badge or '♪',
      subtitle = t('soundboard.play_hint'),
      run = function()
        M.play(clip, config)
      end,
    }
  end
  for _, action in ipairs(actions) do
    action.category = 'Sonidos'
    action.requiresOrigin = false
    action.keywords = 'soundboard audio sonido voicemod tuna'
  end
  return actions
end

return M
