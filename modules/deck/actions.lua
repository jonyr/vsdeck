local aiText = require('modules.ai_text')
local textActions = require('modules.ai_text.actions')
local M = { list = {}, byId = {} }

local function add(action)
  table.insert(M.list, action)
  M.byId[action.id] = action
end

for _, action in ipairs(textActions.list) do
  add({
    id = 'text.' .. action.id, title = action.title, badge = action.badge,
    subtitle = action.subtitle, keywords = action.keywords, category = 'Texto',
    run = function(_, mode) aiText.runAction(action, mode) end
  })
end

local function windowAction(id, title, badge, subtitle, fn)
  add({ id = id, title = title, badge = badge, subtitle = subtitle,
    keywords = 'ventana pantalla monitor', category = 'Ventanas', run = fn })
end

windowAction('window.left', 'Mitad izquierda', '◧', 'Organizar a la izquierda', function(window)
  window:moveToUnit({ x = 0, y = 0, w = 0.5, h = 1 })
end)
windowAction('window.right', 'Mitad derecha', '◨', 'Organizar a la derecha', function(window)
  window:moveToUnit({ x = 0.5, y = 0, w = 0.5, h = 1 })
end)
windowAction('window.maximize', 'Maximizar', '↗', 'Ocupar el área disponible', function(window)
  window:maximize()
end)
windowAction('window.next', 'Otro monitor', '⇥', 'Mover a la siguiente pantalla', function(window)
  window:moveToScreen(window:screen():next())
end)

for _, shortcut in ipairs(require('modules.deck.web_shortcuts')) do
  add({
    id = shortcut.id, title = shortcut.title, badge = shortcut.badge or 'WEB',
    subtitle = (shortcut.browser or 'safari') .. ' · ' .. (shortcut.profile or shortcut.profileDirectory or 'Predeterminado') .. ' · ' .. #shortcut.urls .. ' URL(s)',
    keywords = (shortcut.browser or 'safari') .. ' web perfil ' .. (shortcut.profile or shortcut.profileDirectory or ''), category = 'Web', requiresOrigin = false,
    run = function()
      local ok, err = require('modules.deck.browser').open(shortcut)
      if not ok then hs.notify.new({ title = 'Deck · Web', informativeText = err }):send() end
    end
  })
end

local personal = require('modules.config.personal').data
for _, target in ipairs(personal.snapshots or {}) do
  add({ id=target.id, title=target.title, badge='RDS', category='Tareas',
    subtitle='Snapshot manual de RDS', keywords='aws backup snapshot', requiresOrigin=false,
    run=function() require('modules.tasks.snapshots').run(target) end })
end
for _, job in ipairs(personal.scripts or {}) do
  add({ id=job.id, title=job.title, badge=job.badge or 'RUN', category='Tareas',
    subtitle='Ejecutar script personal', keywords='bash script tarea', requiresOrigin=false,
    run=function() require('modules.tasks.runner').confirmScript(job) end })
end

local hue = personal.hue or {}
for _, light in ipairs(hue.lights or {}) do
  add({ id=light.id, title=light.title, badge='HUE', category='Luces',
    subtitle='Philips Hue · ' .. (light.action or 'toggle'),
    keywords='luz luces hue encender apagar', requiresOrigin=false,
    run=function() require('modules.hue').run(hue, light) end })
end

return M
