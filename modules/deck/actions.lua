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

-- Window actions receive the source window captured before a Deck is opened.
local function windowAction(id, title, badge, subtitle, fn)
  add({
    id = id,
    title = title,
    badge = badge,
    subtitle = subtitle,
    keywords = 'ventana pantalla monitor',
    category = 'Ventanas',
    run = fn,
  })
end

windowAction('window.left', t('window.left.title'), '◧', t('window.left.subtitle'), function(window)
  window:moveToUnit({ x = 0, y = 0, w = 0.5, h = 1 })
end)
windowAction('window.right', t('window.right.title'), '◨', t('window.right.subtitle'), function(window)
  window:moveToUnit({ x = 0.5, y = 0, w = 0.5, h = 1 })
end)
windowAction('window.maximize', t('window.maximize.title'), '↗', t('window.maximize.subtitle'), function(window)
  window:maximize()
end)
windowAction('window.next', t('window.next.title'), '⇥', t('window.next.subtitle'), function(window)
  window:moveToScreen(window:screen():next())
end)

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

local hue = personal.hue or {}
for _, light in ipairs(hue.lights or {}) do
  add({
    id = light.id,
    title = light.title,
    badge = 'HUE',
    category = 'Luces',
    subtitle = t('hue.subtitle', { operation = t('hue.operation.' .. (light.action or 'toggle')) }),
    keywords = 'luz luces hue encender apagar',
    requiresOrigin = false,
    run = function()
      require('modules.hue').run(hue, light)
    end,
  })
end

return M
