--- Expose one shared text job over Hammerspoon's local CLI, without source text.
-- @module modules.streamdeck
local t = require('modules.i18n').t
local notifications = require('modules.notifications')
local ui = require('modules.tasks.ui')
local languages = {
  en = 'English',
  es = 'Spanish',
  pt = 'Portuguese',
  fr = 'French',
  de = 'German',
  it = 'Italian',
  ja = 'Japanese',
  zh = 'Chinese',
  ko = 'Korean',
  nl = 'Dutch',
  ru = 'Russian',
  ar = 'Arabic',
}
local M = {}
local job, deadline
local actionIds =
  { translate = 'translate_en', correct = 'fix_same_language', structure = 'structure', email = 'email' }

--- Return the latest public job state and localized button captions.
function M.status()
  return {
    id = job and job.id or '',
    state = job and job.state or 'idle',
    reason = job and job.reasonKey or '',
    action = job and job.action or 'translate',
    labels = { idle = t('streamdeck.idle'), busy = t('streamdeck.busy'), error = t('streamdeck.error') },
  }
end

--- Accept an idempotent text request; duplicate/busy calls never capture again.
-- @param id Unique opaque request ID; only alphanumerics and hyphens are allowed.
-- @param actionName "translate" (default), "correct", "structure" or "email". All share a clipboard lock.
-- @param settings Optional targetLanguage (English by default) and outputFormat (plain or markdown).
-- @return Public status. Completion is asynchronous; poll status until done/error.
function M.start(id, actionName, settings)
  actionName = actionName or 'translate'
  assert(actionIds[actionName], 'Invalid action')
  settings = settings or {}
  local language = settings.targetLanguage or 'en'
  local outputFormat = settings.outputFormat or 'plain'
  assert(outputFormat == 'plain' or outputFormat == 'markdown', 'Invalid output format')
  assert(languages[language], 'Invalid target language')
  assert(type(id) == 'string' and #id > 0 and #id <= 64 and id:match('^[%w%-]+$'), 'Invalid request ID')
  if job and (job.state == 'busy' or job.id == id) then
    return M.status()
  end
  local current = {
    id = id,
    state = 'busy',
    action = actionName,
    kind = 'text',
    phase = 'text_busy',
    name = (actionName == 'translate' or actionName == 'email') and languages[language] or '',
  }
  job = current
  local operation = {}
  local title = t('streamdeck.notification_title', { action = t('streamdeck.' .. actionName .. '_title') })
  ui.register(current, { title = title }, 'physical')
  ui.update(current)
  local function presentation()
    return {
      title = title,
      final = true,
      present = function()
        ui.toast(current)
      end,
    }
  end
  local errorKeys = {
    ['ai_text.error'] = 'streamdeck.model_error',
    ['ai_text.invalid_response'] = 'streamdeck.response_error',
    ['ai_text.empty_response'] = 'streamdeck.response_error',
    ['ai_text.no_selection'] = 'streamdeck.no_selection',
  }
  -- Keep notifications nonactivating so the source retains focus until paste finishes.
  operation.notifications = { info = function() end, success = function() end }
  local notified = false
  for _, level in ipairs({ 'warning', 'error' }) do
    operation.notifications[level] = function(key, params)
      if notified then
        return
      end
      notified = true
      current.reason = t(errorKeys[key] or key, params)
      ui.update(current)
      notifications[level](errorKeys[key] or key, params, presentation())
    end
  end
  function operation.active()
    return job == current and current.state == 'busy'
  end
  function operation.finish(state, reason)
    if not operation.active() then
      return
    end
    current.state = state
    current.reasonKey = reason
    current.reason = reason and t(reason) or nil
    ui.update(current)
    if state == 'done' then
      notifications.success('task_ui.text_done', nil, presentation())
    end
    if deadline then
      deadline:stop()
      deadline = nil
    end
  end
  deadline = hs.timer.doAfter(120, function()
    operation.finish('error', 'streamdeck.timeout')
    operation.notifications.error('streamdeck.timeout')
  end)
  local ok = pcall(function()
    local presence = package.loaded['modules.discord.presence']
    if presence and presence.isBusy() then
      operation.finish('error', 'discord.presence.busy')
      operation.notifications.error('discord.presence.busy')
      return
    end
    local action
    for _, candidate in ipairs(require('modules.ai_text.actions').list) do
      if candidate.id == actionIds[actionName] then
        action = candidate
        break
      end
    end
    assert(action, 'Action unavailable')
    if actionName == 'translate' or actionName == 'structure' or actionName == 'email' then
      local configured = {}
      for key, value in pairs(action) do
        configured[key] = value
      end
      if actionName == 'translate' then
        configured.prompt = 'Correct errors and translate the text into natural '
          .. languages[language]
          .. '. Preserve the intended tone and level of formality.'
      elseif actionName == 'email' then
        configured.prompt = 'Use the selected text as context to draft a complete, concise, professional email in natural '
          .. languages[language]
          .. '. Write both the subject and the entire body in that target language, regardless of the language of the source. Start with a short subject line labeled with the target-language equivalent of Subject, then a blank line and the email body. Organize the body into readable paragraphs. Preserve supplied facts, dates, amounts, uncertainty, negations, and commitments. Use only the supplied context; do not invent recipient or sender names, signatures, promises, missing facts, or placeholders. Do not add generic greetings or sign-offs if no suitable information is supplied. Return only the subject and body as plain text, without commentary, code fences, HTML, or Markdown formatting. This prepares a draft only; never claim it was sent.'
      else
        configured.prompt = outputFormat == 'markdown' and action.markdownPrompt or action.prompt
      end
      action = configured
    end
    require('modules.ai_text').runAction(action, hs.window.focusedWindow(), operation)
  end)
  if not ok then
    operation.finish('error', 'deck.run_error')
    operation.notifications.error('deck.run_error')
  end
  return M.status()
end

return M
