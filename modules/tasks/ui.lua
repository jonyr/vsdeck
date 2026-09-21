--- Present shared automation task state without owning or interrupting the underlying processes.
-- @module modules.tasks.ui
local i18n = require('modules.i18n')
local M = {}
local jobs, views, controllers, confirmations = {}, {}, {}, {}
local current, menu, lastToast, confirmationTimer
local tab, selected, serial = 'running', '', 0
local function t(key)
  return i18n.t('task_ui.' .. key)
end
local function screenFor(id)
  for _, screen in ipairs(hs.screen.allScreens()) do
    if tostring(screen:id()) == id then
      return screen
    end
  end
  return hs.screen.mainScreen()
end
local function model(job)
  local result = {}
  for _, key in ipairs({
    'kind',
    'pipeline',
    'executionId',
    'executionStatus',
    'startedAt',
    'artifacts',
    'empty',
    'uid',
    'state',
    'phase',
    'reason',
    'name',
    'account',
    'profile',
    'region',
    'instance',
    'title',
    'origin',
    'time',
  }) do
    result[key] = job[key]
  end
  return result
end
local function render(kind, job)
  local list = {}
  for _, item in ipairs(jobs) do
    list[#list + 1] = model(item)
  end
  local data = {
    kind = kind,
    jobs = list,
    job = job and model(job),
    tab = tab,
    selected = selected,
    strings = i18n.catalog('task_ui.'),
  }
  local file = assert(io.open(hs.configdir .. '/modules/tasks/ui.html'))
  local html = file:read('*a')
  file:close()
  local json = hs.json.encode(data):gsub('<', '\\u003c')
  views[kind]:html((html:gsub('__TASK_DATA__', function()
    return json
  end)))
end
local dispatch
local function show(kind, job, focus)
  local frame = screenFor(job and job.screenId):frame()
  local w, h = 540, 620
  if kind == 'confirm' then
    w, h = 490, 490
  elseif kind == 'toast' then
    w, h = 410, 146
  end
  w, h = math.min(w, frame.w), math.min(h, frame.h)
  local rect = { x = frame.x + (frame.w - w) / 2, y = frame.y + (frame.h - h) / 2, w = w, h = h }
  if kind == 'toast' then
    rect.x, rect.y = math.max(frame.x, frame.x + frame.w - w - 18), frame.y + 18
  end
  if not views[kind] then
    controllers[kind] = hs.webview.usercontent.new('taskUI' .. kind):setCallback(function(message)
      dispatch(kind, message.body)
    end)
    views[kind] = hs.webview
      .new(rect, { javaScriptCanOpenWindowsAutomatically = false, privateBrowsing = true }, controllers[kind])
      :windowStyle(kind == 'toast' and { 'borderless', 'nonactivating' } or { 'borderless' })
      :windowTitle(t(kind == 'confirm' and 'confirm_title' or 'center_title'))
      :darkMode(false)
      :shadow(true)
      :allowTextEntry(kind ~= 'toast')
      :allowNewWindows(false)
      :deleteOnClose(false)
      :closeOnEscape(true)
      :windowCallback(function(event)
        if event == 'closing' and kind == 'confirm' and current then
          dispatch('confirm', { action = 'cancel', id = current.uid })
        end
      end)
    if kind == 'toast' then
      views[kind]:level(hs.drawing.windowLevels.floating)
    end
  end
  views[kind]:frame(rect)
  render(kind, job)
  views[kind]:show()
  if focus then
    views[kind]:bringToFront(true):hswindow():focus()
  end
end
local function refresh()
  if views.center then
    render('center')
  end
end
local function nextConfirmation()
  if current or confirmationTimer then
    return
  end
  for _, job in ipairs(jobs) do
    if confirmations[job.uid] then
      current = job
      local ok, err = pcall(show, 'confirm', job, true)
      if not ok then
        local callback = confirmations[job.uid]
        confirmations[job.uid], current = nil, nil
        if callback then
          callback(false)
        end
        error(err)
      end
      return
    end
  end
end
--- Register a task and capture its originating display before asynchronous inspection.
function M.register(job, target, origin)
  serial = serial + 1
  job.uid, job.origin, job.time = tostring(serial), origin, os.date('%H:%M')
  for _, key in ipairs({ 'title', 'profile', 'region', 'instance', 'pipeline' }) do
    job[key] = target[key]
  end
  local window = require('modules.tasks.source_window').capture()
  local screen = window and window:screen()
  if not screen then
    local point = hs.mouse.absolutePosition()
    for _, candidate in ipairs(hs.screen.allScreens()) do
      local f = candidate:fullFrame()
      if point.x >= f.x and point.x < f.x + f.w and point.y >= f.y and point.y < f.y + f.h then
        screen = candidate
        break
      end
    end
  end
  job.screenId = tostring((screen or hs.screen.mainScreen()):id())
  jobs[#jobs + 1] = job
  if #jobs > 100 then
    for index, item in ipairs(jobs) do
      if item.state ~= 'busy' then
        table.remove(jobs, index)
        break
      end
    end
  end
  if not menu then
    menu = hs.menubar.new():setTitle('VS Tasks'):setMenu({ { title = t('open'), fn = M.open } })
  end
end
--- Reflect real phases; background updates never reopen a dismissed center.
function M.update(job)
  if job.kind == 'pipeline' and selected == job.uid then
    tab = job.state == 'error' and 'attention' or job.state == 'busy' and 'running' or 'history'
  end
  refresh()
  if job.phase == 'inspect' and not (views.center and views.center:isVisible()) then
    tab = 'running'
    show('center', job, true)
  end
end
--- Remove terminal records from this UI session without changing jobs in their owners.
-- Active work and outstanding confirmation callbacks are always retained.
-- @return Number of records removed.
function M.clearHistory()
  local removed = 0
  for index = #jobs, 1, -1 do
    local job = jobs[index]
    local terminal = job.state == 'done' or job.state == 'error' or job.state == 'cancelled'
    if terminal and not confirmations[job.uid] and job ~= current then
      table.remove(jobs, index)
      removed = removed + 1
      if selected == job.uid then
        selected = ''
      end
      if lastToast == job then
        lastToast = nil
        if views.toast then
          views.toast:hide()
        end
      end
    end
  end
  refresh()
  return removed
end
--- Request an asynchronous, single-use confirmation; concurrent destinations are queued.
function M.confirm(job, callback)
  confirmations[job.uid] = callback
  tab = 'attention'
  refresh()
  nextConfirmation()
end
--- Show a completion toast. Called only through modules.notifications.
function M.toast(job)
  lastToast = job
  show('toast', job, false)
end
--- Open session history without starting any task.
function M.open()
  show('center', lastToast or jobs[#jobs], true)
end
--- Open a selected task in the common center, retaining details through updates.
function M.reveal(job)
  selected = job.uid
  tab = job.state == 'busy' and 'running' or job.state == 'error' and 'attention' or 'history'
  show('center', job, true)
end
local function decide(accepted)
  local job = current
  if not job then
    return
  end
  local callback = confirmations[job.uid]
  confirmations[job.uid], current = nil, nil
  views.confirm:hide()
  if accepted then
    tab = 'running'
  end
  -- Clear the callback before invocation so duplicate/stale UI events cannot create twice.
  if callback then
    callback(accepted)
  end
  refresh()
  -- Let a native close finish before presenting the next queued window.
  confirmationTimer = hs.timer.doAfter(0, function()
    confirmationTimer = nil
    local ok, err = pcall(nextConfirmation)
    if not ok then
      require('modules.notifications').error('task_ui.unavailable')
      print('[task UI] ' .. tostring(err))
    end
  end)
end
dispatch = function(kind, body)
  if type(body) ~= 'table' then
    return
  end
  if kind == 'confirm' and current and body.id == current.uid then
    if body.action == 'confirm' or body.action == 'cancel' then
      decide(body.action == 'confirm')
    end
  elseif kind == 'center' and body.action == 'tab' then
    if body.tab == 'attention' or body.tab == 'running' or body.tab == 'history' then
      tab = body.tab
      refresh()
    end
  elseif kind == 'center' and body.action == 'clearHistory' then
    M.clearHistory()
  elseif kind == 'center' and body.action == 'artifact' then
    for _, job in ipairs(jobs) do
      if job.uid == body.id and job.kind == 'pipeline' and type(body.index) == 'number' then
        local artifact = job.artifacts and job.artifacts[body.index]
        local url = artifact and artifact.revisionUrl
        if type(url) == 'string' and url:match('^https://[^/%s]+') and not url:find('%c') then
          hs.urlevent.openURL(url)
        end
        break
      end
    end
  elseif kind == 'center' and body.action == 'review' then
    for _, job in ipairs(jobs) do
      if job.uid == body.id and confirmations[job.uid] then
        current = job
        show('confirm', job, true)
        break
      end
    end
  elseif kind == 'toast' and body.action == 'open' and lastToast and body.id == lastToast.uid then
    selected = lastToast.uid
    tab = lastToast.state == 'error' and 'attention' or 'history'
    M.open()
  elseif body.action == 'dismiss' and (kind == 'center' or kind == 'toast') then
    views[kind]:hide()
  end
end
return M
