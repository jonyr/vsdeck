local function actionById(id)
  for _, action in ipairs(require('modules.ai_text.actions').list) do
    if action.id == id then
      return action
    end
  end
  error('Unknown action: ' .. id)
end
--- Exercise bridge lifecycle with real capture/model/delivery modules and offline APIs.
-- @script tests.streamdeck_test
local tasks, response, focused, axText, clipboard, version, pastes, httpCalls
local lastPrompt
local app = {}
local window = {
  id = function()
    return 1
  end,
  application = function()
    return app
  end,
}
package.loaded['config'] = { pasteDelay = 0.15, copyDelay = 0.2, copyTimeout = 0.3 }
package.loaded['modules.config.personal'] = { data = {} }
package.loaded['modules.ai_text.app_context'] = {
  styleInstruction = function()
    return ''
  end,
}
local textJobs = {}
package.loaded['modules.tasks.ui'] = {
  register = function(job, target)
    job.title = target.title
    textJobs[#textJobs + 1] = job
  end,
  update = function() end,
  toast = function() end,
}
local notices = {}
local notifier = {}
for _, level in ipairs({ 'info', 'error', 'warning', 'success' }) do
  notifier[level] = function(key, params, options)
    notices[#notices + 1] = { level = level, key = key, params = params, options = options }
  end
end
package.loaded['modules.notifications'] = notifier
hs = {
  timer = {
    doAfter = function(delay, callback)
      local task = { delay = delay, callback = callback, stopped = false }
      function task:stop()
        self.stopped = true
      end
      tasks[#tasks + 1] = task
      return task
    end,
  },
  window = {
    focusedWindow = function()
      return focused
    end,
  },
  axuielement = {
    applicationElement = function()
      return {
        attributeValue = function()
          return {
            attributeValue = function()
              return axText
            end,
          }
        end,
      }
    end,
  },
  pasteboard = {
    getContents = function()
      return clipboard
    end,
    changeCount = function()
      return version
    end,
    setContents = function(value)
      clipboard = value
      version = version + 1
    end,
  },
  eventtap = {
    keyStroke = function(_, key)
      if key == 'v' then
        pastes = pastes + 1
      end
    end,
  },
  json = {
    encode = function(value)
      if value.messages then
        lastPrompt = value.messages[1].content
      end
      return '{}'
    end,
    decode = function(body)
      if body == 'invalid' then
        error('bad json')
      end
      return body
    end,
  },
  http = {
    asyncPost = function(_, _, _, callback)
      response = callback
      httpCalls = httpCalls + 1
    end,
  },
}
local function reset()
  notices = {}
  tasks, focused, axText, clipboard, version, pastes, httpCalls, response = {}, window, 'Hola', 'old', 1, 0, 0, nil
  package.loaded['modules.streamdeck'] = nil
  return require('modules.streamdeck')
end
local function reply(text)
  response(200, { choices = { { message = { content = text } } } })
end
local function tick(delay)
  for _, task in ipairs(tasks) do
    if not task.stopped and task.delay == delay then
      task.stopped = true
      task.callback()
      return
    end
  end
  error('Missing timer')
end
local bridge = reset()
assert(bridge.start('one').state == 'busy')
assert(bridge.start('two').id == 'one' and httpCalls == 1)
reply('Hello')
assert(bridge.status().state == 'busy' and pastes == 0)
tick(0.15)
assert(bridge.status().state == 'done' and pastes == 1)
assert(bridge.start('one').state == 'done' and httpCalls == 1)
bridge = reset()
bridge.start('one')
response(503, '')
assert(bridge.status().state == 'error')
bridge = reset()
bridge.start('one')
response(200, 'invalid')
assert(bridge.status().state == 'error')
bridge = reset()
bridge.start('one')
reply('')
assert(bridge.status().state == 'error')
bridge = reset()
focused = nil
assert(bridge.start('one').state == 'error' and httpCalls == 0)
assert(bridge.status().reason == 'ai_text.capture_failed')
bridge = reset()
axText = nil
bridge.start('one')
tick(0.2)
tick(0.05)
assert(bridge.status().state == 'error' and httpCalls == 0)
bridge = reset()
bridge.start('one')
reply('Hello')
focused = nil
tick(0.15)
assert(bridge.status().state == 'error' and pastes == 0 and clipboard == 'Hello')
assert(bridge.status().reason == 'ai_text.result_copy_only')
bridge = reset()
bridge.start('one')
reply('Hello')
hs.pasteboard.setContents('User copy')
tick(0.15)
assert(bridge.status().state == 'error' and pastes == 0 and clipboard == 'User copy')
bridge = reset()
bridge.start('one')
local late = response
tick(120)
assert(bridge.status().state == 'error')
bridge.start('two')
late(200, { choices = { { message = { content = 'Too late' } } } })
assert(bridge.status().id == 'two' and bridge.status().state == 'busy' and clipboard == 'old')
reply('Hello')
tick(0.15)
assert(pastes == 1)
bridge = reset()
bridge.start('one')
reply('Hello')
tick(120)
tick(0.15)
assert(bridge.status().state == 'error' and pastes == 0)
assert(not pcall(bridge.start, "bad'id"))
print('PASS: translation lifecycle, duplicates, failures, focus, timeout and stale callbacks without external effects.')

for _, body in ipairs({
  false,
  17,
  { choices = 'invalid' },
  { choices = { 17 } },
  { choices = { { message = { content = {} } } } },
}) do
  bridge = reset()
  bridge.start('invalid-shape')
  response(200, body)
  assert(bridge.status().state == 'error')
end

bridge = reset()
assert(bridge.start('correction', 'correct').action == 'correct')
assert(lastPrompt:find('Preserve the original language, voice, and tone.', 1, true))
assert(not lastPrompt:find('translate the text into natural English', 1, true))
assert(bridge.start('blocked', 'translate').id == 'correction' and httpCalls == 1)
reply('Texto corregido')
tick(0.15)
assert(bridge.status().state == 'done' and clipboard == 'Texto corregido')
assert(bridge.start('translation', 'translate').action == 'translate' and httpCalls == 2)
assert(not pcall(bridge.start, 'invalid', 'unknown'))
print('PASS: shared correction/translation lock and action selection.')

-- Completion and failures use the shared center without opening it during paste.
bridge = reset()
bridge.start('quiet-success', 'correct')
reply('Texto corregido')
tick(0.15)
assert(#notices == 1 and notices[1].level == 'success')
assert(type(notices[1].options.present) == 'function')
assert(textJobs[#textJobs].kind == 'text' and textJobs[#textJobs].state == 'done')
bridge = reset()
bridge.start('model-failure', 'correct')
response(503, '')
assert(#notices == 1 and notices[1].level == 'error')
assert(notices[1].key == 'streamdeck.model_error' and notices[1].params.status == 503)
assert(notices[1].options.final == true)
assert(notices[1].options.title:find(require('modules.i18n').t('streamdeck.correct_title'), 1, true))
response(503, '')
assert(#notices == 1)
bridge = reset()
bridge.start('copy-only', 'translate')
reply('Hello')
focused = nil
tick(0.15)
assert(#notices == 1 and notices[1].key == 'ai_text.result_copy_only' and notices[1].level == 'warning')
bridge = reset()
bridge.start('timeout', 'correct')
tick(120)
assert(#notices == 1 and notices[1].key == 'streamdeck.timeout' and notices[1].options.final)
print('PASS: shared notifications, completion toasts, actionable errors, action titles and no duplicate alerts.')

bridge = reset()
bridge.start('french', 'translate', { targetLanguage = 'fr' })
assert(lastPrompt:find('natural French', 1, true))
assert(actionById('translate_en').prompt:find('natural English', 1, true))
assert(not pcall(bridge.start, 'bad-language', 'translate', { targetLanguage = 'invalid' }))
print('PASS: target language reaches model without changing shared prompt defaults.')

-- Structure uses the same guarded replacement and never stores the generated text in history.
bridge = reset()
bridge.start('structure-test', 'structure')
assert(bridge.status().action == 'structure' and bridge.status().state == 'busy')
assert(lastPrompt:find('original language and tone', 1, true))
assert(lastPrompt:find('standalone title and • bullets', 1, true))
assert(lastPrompt:find('do not summarize away information or invent facts', 1, true))
assert(bridge.start('blocked-structure', 'translate').id == 'structure-test')
local organized = 'Plan de trabajo\n\nRevisar el proyecto.\n\n• Revisar fechas\n• Confirmar responsables'
reply(organized)
tick(0.15)
assert(clipboard == organized and bridge.status().state == 'done')
assert(#notices == 1 and notices[1].level == 'success')
assert(notices[1].options.title:find('Structure', 1, true))
assert(textJobs[#textJobs].text == nil and textJobs[#textJobs].result == nil)
print('PASS: Structure prompt, shared lock, multiline replacement and metadata-only task completion.')

bridge = reset()
assert(not pcall(bridge.start, 'bad-format', 'structure', { outputFormat = 'html' }))
bridge.start('markdown-test', 'structure', { outputFormat = 'markdown' })
assert(lastPrompt:find('Use # for the main title', 1, true))
assert(not lastPrompt:find('without a preamble, code fence, HTML, or Markdown heading/bold markers', 1, true))
local markdown = '# Plan de trabajo\n\nRevisar el proyecto.\n\n- Revisar fechas\n- Confirmar responsables'
reply(markdown)
tick(0.15)
assert(clipboard == markdown and bridge.status().state == 'done')
assert(actionById('structure').prompt:find('as plain text', 1, true))
print('PASS: Markdown output reaches the model and paste without changing the plain default.')

-- Email drafts use the configured language without changing the base prompt.
bridge = reset()
local originalEmailPrompt = actionById('email').prompt
bridge.start('email-spanish', 'email', { targetLanguage = 'es' })
assert(bridge.status().action == 'email' and bridge.status().state == 'busy')
assert(lastPrompt:find('email in natural Spanish', 1, true))
assert(lastPrompt:find('both the subject and the entire body', 1, true))
assert(lastPrompt:find('do not invent recipient or sender names', 1, true))
assert(bridge.start('email-blocked', 'translate').id == 'email-spanish')
local draft = 'Asunto: Revisión del proyecto\n\nLa revisión será el viernes a las 10.'
reply(draft)
tick(0.15)
assert(clipboard == draft and bridge.status().state == 'done')
assert(#notices == 1 and notices[1].level == 'success')
assert(notices[1].options.title:find('Email', 1, true))
assert(actionById('email').prompt == originalEmailPrompt)
bridge = reset()
bridge.start('email-default', 'email')
assert(lastPrompt:find('email in natural English', 1, true))
print('PASS: email context, chosen/default language, subject/body replacement and unchanged base prompt.')
