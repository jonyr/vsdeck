--- Manage the HTML Deck webview, its message bridge and menu-bar entry.
-- @module modules.deck.init

local t = require('modules.i18n').t
local actions = require('modules.deck.actions')
local M = {}
-- Retain webview, bridge and hotkeys for the module lifetime.
local view, controller, origin, hotkey, escapeKey, menuItem
local executor = require('modules.deck.executor').new()

local function notify(message)
  require('modules.notifications').text('error', message)
end

--- Hide the webview and release its Escape binding.
function M.hide()
  if view then
    view:hide()
  end
  if escapeKey then
    escapeKey:disable()
  end
end

-- Accept only known IDs and modes from the webview; never execute client-provided code.
local function dispatch(message)
  local body = message.body
  if type(body) ~= 'table' then
    return
  end
  if body.type == 'close' then
    M.hide()
    return
  end
  if body.type ~= 'run' or executor.isBusy() or not view:isVisible() then
    return
  end
  local action = actions.byId[body.id]
  if not action or (body.mode ~= 'copy' and body.mode ~= 'replace') then
    return
  end
  executor.run(action, origin, body.mode)
end

--- Open the panel with localized public metadata and remember the source window.
function M.show()
  if executor.isBusy() then
    return
  end
  if view and view:isVisible() then
    view:hswindow():focus()
    return
  end
  origin = hs.window.focusedWindow()
  local screen = origin and origin:screen() or hs.screen.mainScreen()
  local frame = screen:frame()
  local w, h = math.min(860, frame.w - 40), math.min(660, frame.h - 60)
  local rect = { x = frame.x + (frame.w - w) / 2, y = frame.y + (frame.h - h) / 2, w = w, h = h }
  -- Create the bridge and view once; hiding the panel must not destroy its controller.
  if not view then
    controller = hs.webview.usercontent.new('deck'):setCallback(dispatch)
    view = hs.webview
      .new(rect, { javaScriptCanOpenWindowsAutomatically = false }, controller)
      :windowStyle({ 'titled', 'closable' })
      :windowTitle('Deck')
      :level(hs.drawing.windowLevels.floating)
      :allowTextEntry(true)
      :allowNewWindows(false)
      :allowNavigationGestures(false)
      :deleteOnClose(false)
      :closeOnEscape(true)
      :windowCallback(function(event)
        if event == 'closing' and escapeKey then
          escapeKey:disable()
        end
      end)
  end
  local file = io.open(hs.configdir .. '/modules/deck/panel.html', 'r')
  if not file then
    notify(t('deck.load_error'))
    return
  end
  local html = file:read('*a')
  file:close()
  local catalog = {}
  for _, action in ipairs(actions.list) do
    table.insert(catalog, {
      id = action.id,
      title = action.title,
      badge = action.badge,
      subtitle = action.subtitle .. (require('modules.tasks.runner').states[action.id] and (' · ' .. t(
        'state.' .. require('modules.tasks.runner').states[action.id]
      )) or ''),
      keywords = action.keywords,
      category = action.category,
    })
  end
  -- Only public display metadata crosses into the webview; never configuration or secrets.
  local data = hs.json.encode(catalog):gsub('<', '\\u003c')
  local i18n = require('modules.i18n')
  local messages = i18n.catalog('deck.')
  for key, value in pairs(i18n.catalog('category.')) do
    messages[key] = value
  end
  local locale = hs.json.encode({ language = i18n.language(), messages = messages }):gsub('<', '\\u003c')
  html = html:gsub('__DECK_LOCALE__', function()
    return locale
  end)
  html = html:gsub('__DECK_ACTIONS__', function()
    return data
  end)
  view:frame(rect):html(html):show()
  if not escapeKey then
    escapeKey = hs.hotkey.new({}, 'escape', M.hide)
  end
  escapeKey:enable()
  view:hswindow():focus()
end

--- Toggle visibility without recreating an already retained webview.
function M.toggle()
  if view and view:isVisible() then
    M.hide()
  else
    M.show()
  end
end

--- Replace the global HTML Deck shortcut.
function M.bindHotkeys(modifiers, key)
  if hotkey then
    hotkey:delete()
  end
  hotkey = hs.hotkey.bind(modifiers, key or 'D', M.toggle)
end

--- Create the menu-bar toggle once per module lifetime.
function M.setupMenubar()
  if menuItem then
    return
  end
  menuItem = hs.menubar.new()
  if not menuItem then
    notify(t('deck.menubar_error'))
    return
  end
  menuItem:setTitle('🔘'):setTooltip(t('deck.tooltip')):setClickCallback(M.toggle)
end

-- Release retained UI objects when replacing this module without reloading tasks.
--- Release UI objects and pending dispatch without cancelling background tasks.
function M.stop()
  M.hide()
  executor.cancel()
  if hotkey then
    hotkey:delete()
    hotkey = nil
  end
  if escapeKey then
    escapeKey:delete()
    escapeKey = nil
  end
  if menuItem then
    menuItem:delete()
    menuItem = nil
  end
  if view then
    view:delete()
    view = nil
  end
  controller = nil
end

return M
