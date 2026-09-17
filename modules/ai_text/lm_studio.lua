local appContext = require('modules.ai_text.app_context')

local json = hs.json

local M = {}

local function stripReasoning(text)
  if not text then
    return ''
  end

  text = text:gsub('<think>.-</think>', '')
  text = text:gsub('^%s+', '')
  text = text:gsub('%s+$', '')
  return text
end

local function buildPayload(config, action, selectedText)
  local systemPrompt = table.concat({
    'You are a professional editor and translator.',
    'Return only the final rewritten text.',
    'Do not explain what you changed.',
    'Do not wrap the answer in quotes.',
    'Preserve Markdown, bullet lists, code blocks, commands, URLs, file paths, and identifiers unless the user text clearly asks otherwise.',
    appContext.styleInstruction()
  }, ' ')

  local userPrompt = action.prompt .. '\n\nText:\n' .. selectedText

  return json.encode({
    model = config.model,
    temperature = 0.2,
    stream = false,
    messages = {
      {
        role = 'system',
        content = systemPrompt
      },
      {
        role = 'user',
        content = userPrompt
      }
    }
  })
end

function M.call(config, action, selectedText, callback)
  hs.notify.new({ title = 'Custom Alert', informativeText = 'Procesando con LM Studio...' }):send()

  hs.http.asyncPost(
    config.lmStudioUrl,
    buildPayload(config, action, selectedText),
    { ['Content-Type'] = 'application/json' },
    function(status, body)
      if status ~= 200 then
        hs.notify.new({ title = 'Custom Alert', informativeText = 'LM Studio error: ' .. tostring(status) }):send()
        return
      end

      local ok, response = pcall(json.decode, body)
      if not ok or not response or not response.choices or not response.choices[1] then
        hs.notify.new({ title = 'Custom Alert', informativeText = 'Respuesta invalida de LM Studio' }):send()
        return
      end

      local message = response.choices[1].message
      local result = message and message.content or nil
      result = stripReasoning(result)

      if result == '' then
        hs.notify.new({ title = 'Custom Alert', informativeText = 'LM Studio devolvio texto vacio' }):send()
        return
      end

      callback(result)
    end
  )
end

return M
