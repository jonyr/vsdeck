--- Verify simulated windows, monitor routing and lifecycle without real apps or AWS.
package.path = './?.lua;./?/init.lua;' .. package.path
package.loaded['modules.config.personal'] = { data = {} }
local function screen(id, x)
  return {
    id = function()
      return id
    end,
    name = function()
      return 'Screen ' .. id
    end,
    frame = function()
      return { x = x, y = 0, w = 1200, h = 900 }
    end,
    fullFrame = function()
      return { x = x, y = 0, w = 1200, h = 900 }
    end,
  }
end
local a, b = screen(1, 0), screen(2, 1200)
local screens = { a, b }
local source = {
  screen = function()
    return b
  end,
}
package.loaded['modules.tasks.source_window'] = {
  capture = function()
    return source
  end,
}
local controllers, views, timers = {}, {}, {}
local focused = 0
local renderedData
hs = {
  configdir = '.',
  screen = {
    allScreens = function()
      return screens
    end,
    mainScreen = function()
      return a
    end,
  },
  mouse = {
    absolutePosition = function()
      return { x = 1300, y = 50 }
    end,
  },
  drawing = { windowLevels = { floating = 3 } },
  json = {
    encode = function(data)
      renderedData = data
      return '{}'
    end,
  },
  timer = {
    doAfter = function(_, fn)
      local timer = {
        fn = fn,
        stop = function(self)
          self.stopped = true
        end,
      }
      timers[#timers + 1] = timer
      return timer
    end,
  },
  menubar = {
    new = function()
      local menu = {}
      function menu:setTitle()
        return self
      end
      function menu:setMenu()
        return self
      end
      function menu:delete() end
      return menu
    end,
  },
  webview = {
    usercontent = {
      new = function(name)
        local controller = {
          name = name,
          setCallback = function(self, fn)
            self.fn = fn
            return self
          end,
        }
        controllers[name] = controller
        return controller
      end,
    },
    new = function(rect, _, controller)
      local view = { rect = rect, visible = false, focuses = 0 }
      for _, method in ipairs({
        'windowStyle',
        'windowTitle',
        'darkMode',
        'shadow',
        'allowTextEntry',
        'allowNewWindows',
        'deleteOnClose',
        'closeOnEscape',
        'level',
      }) do
        view[method] = function(self, value)
          self[method .. 'Value'] = value
          return self
        end
      end
      function view:windowCallback(fn)
        self.callback = fn
        return self
      end
      function view:frame(value)
        self.rect = value
        return self
      end
      function view:html(value)
        assert(value:find('taskUI', 1, true))
        self.content = value
        return self
      end
      function view:show()
        self.visible = true
        return self
      end
      function view:hide()
        self.visible = false
        return self
      end
      function view:isVisible()
        return self.visible
      end
      function view:bringToFront()
        self.focuses = self.focuses + 1
        return self
      end
      function view:hswindow()
        return {
          screen = function()
            return self.rect.x >= 1200 and b or a
          end,
          focus = function()
            focused = focused + 1
          end,
        }
      end
      function view:delete()
        self.deleted = true
      end
      views[controller.name] = view
      return view
    end,
  },
}
hs.window = {
  focusedWindow = function()
    return source
  end,
}
local ui = require('modules.tasks.ui')
local function send(kind, body)
  controllers['taskUI' .. kind].fn({ body = body })
end
local function job(instance)
  local item = { state = 'busy', phase = 'inspect' }
  ui.register(item, { title = 'Backup', profile = 'work', region = 'us-east-1', instance = instance }, 'physical')
  ui.update(item)
  return item
end
local first, second = job('hotel-a'), job('hotel-b')
local responses = {}
first.phase, second.phase = 'confirm', 'confirm'
ui.confirm(first, function(choice)
  responses[#responses + 1] = choice
  first.state = 'cancelled'
  first.phase = 'cancelled'
end)
ui.confirm(second, function(choice)
  responses[#responses + 1] = choice
  second.phase = 'create'
end)
assert(views.taskUIconfirm.windowStyleValue[1] == 'borderless')
send('confirm', { action = 'confirm', id = 'stale' })
assert(#responses == 0)
views.taskUIconfirm.callback('closing')
assert(not views.taskUIconfirm.visible)
timers[#timers].fn()
assert(
  #responses == 1 and responses[1] == false and views.taskUIconfirm.visible,
  'closing first must cancel and present the queued confirmation'
)
send('confirm', { action = 'confirm', id = first.uid })
assert(#responses == 1, 'old confirmation must not accept the next task')
send('confirm', { action = 'confirm', id = second.uid })
send('confirm', { action = 'confirm', id = second.uid })
assert(#responses == 2 and responses[2] == true)
send('center', { action = 'dismiss' })
second.phase = 'waiting'
ui.update(second)
assert(not views.taskUIcenter.visible, 'updates must not reopen a hidden center')
local before = focused
second.state = 'done'
second.phase = 'available'
ui.update(second)
ui.toast(second)
assert(focused == before and views.taskUItoast.windowStyleValue[2] == 'nonactivating')
screens = { a }
send('toast', { action = 'open', id = second.uid })
assert(views.taskUIcenter.visible and views.taskUIcenter.rect.x < 1200)
assert(package.loaded['modules.tasks.snapshots'] == nil and package.loaded['modules.tasks.runner'] == nil)
print(
  'PASS: task UI confirmation queue, stale events, cancellation, hidden progress, completion focus and monitor fallback.'
)

local opened = {}
hs.urlevent = {
  openURL = function(url)
    opened[#opened + 1] = url
  end,
}
local pipeline = { kind = 'pipeline', state = 'busy', phase = 'pipeline_read', artifacts = {} }
ui.register(pipeline, { title = 'Pipeline', profile = 'work', region = '', pipeline = 'example' }, 'physical')
ui.reveal(pipeline)
pipeline.state = 'done'
pipeline.artifacts = { { revisionUrl = 'https://example.com/commit' }, { revisionUrl = 'javascript:alert(1)' } }
ui.update(pipeline)
send('center', { action = 'artifact', id = pipeline.uid, index = 1 })
send('center', { action = 'artifact', id = pipeline.uid, index = 2 })
send('center', { action = 'artifact', id = 'stale', index = 1 })
assert(#opened == 1 and opened[1] == 'https://example.com/commit')
send('center', { action = 'dismiss' })
ui.update(pipeline)
assert(not views.taskUIcenter.visible, 'completed query must not reopen a dismissed center')

-- History removal must not touch the task objects, active processes or pending confirmations.
local running = job('running')
running.phase = 'waiting'
local pending = job('pending')
pending.phase = 'confirm'
local confirmed = false
timers[#timers].fn() -- Complete the previous confirmation window closing.
ui.confirm(pending, function()
  confirmed = true
end)
local failed = job('failed')
failed.state, failed.phase = 'error', 'error'
ui.toast(failed)
send('center', { action = 'clearHistory' })
assert(#renderedData.jobs == 2)
assert(renderedData.jobs[1].uid == running.uid and renderedData.jobs[2].uid == pending.uid)
assert(running.state == 'busy' and pending.state == 'busy' and not confirmed)
assert(second.state == 'done' and pipeline.state == 'done' and failed.state == 'error')
assert(not views.taskUItoast.visible)
assert(ui.clearHistory() == 0)
ui.update(failed)
assert(#renderedData.jobs == 2, 'a stale update must not resurrect deleted records')
send('confirm', { action = 'confirm', id = pending.uid })
assert(confirmed, 'clearing history must preserve pending confirmation callbacks')
print('PASS: clear history removes terminal records, retains active jobs and confirmations, and ignores stale updates.')

-- Script selections must cross the existing single-use confirmation boundary intact.
timers[#timers].fn()
local scriptJob =
  { kind = 'script', state = 'busy', phase = 'confirm', inputs = {}, selection = {}, message = 'Choose' }
ui.register(scriptJob, { title = 'Script' }, 'physical')
local selected, invocations = nil, 0
ui.confirm(scriptJob, function(accepted, values)
  assert(accepted)
  selected, invocations = values, invocations + 1
end)
send('confirm', { action = 'confirm', id = scriptJob.uid, values = { app = 'backend' } })
send('confirm', { action = 'confirm', id = scriptJob.uid, values = { app = 'frontend' } })
assert(selected.app == 'backend' and invocations == 1)
scriptJob.state, scriptJob.message, scriptJob.logs = 'done', 'Tag sales publicado', 'log output'
ui.reveal(scriptJob)
assert(renderedData.tab == 'history' and renderedData.jobs[#renderedData.jobs].logs == 'log output')
print('PASS: script form selection, single-use submission and history details.')
