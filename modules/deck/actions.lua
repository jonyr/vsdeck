--- Build the shared action catalog used by both Deck interfaces.
-- @module modules.deck.actions

local t = require('modules.i18n').t
local aiText = require('modules.ai_text')
local textActions = require('modules.ai_text.actions')
local M = { list = {}, byId = {} }

local function add(action)
  table.insert(M.list, action)
  M.byId[action.id] = action
end

-- Both interfaces reuse the same text action objects and execution path.
for _, action in ipairs(textActions.list) do
  add({
    id = 'text.' .. action.id,
    title = action.title,
    badge = action.badge,
    subtitle = action.subtitle,
    keywords = action.keywords,
    category = 'Texto',
    run = function(window, mode)
      aiText.runAction(action, mode, window)
    end,
  })
end

-- Geometry actions operate directly on the source window without keyboard focus.
for _, item in ipairs({ { 'left', '◧' }, { 'right', '◨' }, { 'maximize', '↗' }, { 'next', '⇥' } }) do
  local operation = item[1]
  add({
    id = 'window.' .. operation,
    title = t('window.' .. operation .. '.title'),
    badge = item[2],
    subtitle = t('window.' .. operation .. '.subtitle'),
    keywords = 'ventana pantalla monitor',
    category = 'Ventanas',
    requiresFocus = false,
    run = function(window)
      require('modules.deck.windows').run(operation, window)
    end,
  })
end

-- Web actions do not require a source window and keep user-defined titles unchanged.
for _, shortcut in ipairs(require('modules.deck.web_shortcuts')) do
  add({
    id = shortcut.id,
    title = shortcut.title,
    badge = shortcut.badge or 'WEB',
    subtitle = (shortcut.browser or 'safari') .. ' · ' .. (shortcut.profile or shortcut.profileDirectory or t(
      'common.default'
    )) .. ' · ' .. t('web.url_count', { count = #shortcut.urls }),
    keywords = (shortcut.browser or 'safari')
      .. ' web perfil '
      .. (shortcut.profile or shortcut.profileDirectory or ''),
    category = 'Web',
    requiresOrigin = false,
    run = function()
      local ok, err = require('modules.deck.browser').open(shortcut)
      if not ok then
        require('modules.notifications').text('error', err)
      end
    end,
  })
end

-- Optional integrations are registered only when configured for this installation.
local personal = require('modules.config.personal').data
for _, action in ipairs(require('modules.soundboard').actions(personal.soundboard or {})) do
  add(action)
end
for _, target in ipairs(personal.snapshots or {}) do
  add({
    id = target.id,
    title = target.title,
    badge = 'RDS',
    category = 'Tareas',
    subtitle = t('tasks.snapshot.subtitle'),
    keywords = 'aws backup snapshot',
    requiresOrigin = false,
    run = function()
      require('modules.tasks.snapshots').run(target)
    end,
  })
end
for _, job in ipairs(personal.scripts or {}) do
  add({
    id = job.id,
    title = job.title,
    badge = job.badge or 'RUN',
    category = 'Tareas',
    subtitle = t('tasks.script.subtitle'),
    keywords = 'bash script tarea',
    requiresOrigin = false,
    run = function()
      require('modules.tasks.runner').confirmScript(job)
    end,
  })
end

-- Both interfaces share the same Hue presets and live state.
for _, action in ipairs(require('modules.hue.actions').build(personal.hue or {})) do
  add(action)
end

-- Voice controls target Discord itself rather than the captured source window.
for _, action in ipairs(require('modules.discord').actions()) do
  add(action)
end

return M
