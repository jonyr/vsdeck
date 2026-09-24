--- Verify provider isolation and credential handling without network, clipboard or real keys.
local posted, notice, finished, result
local permissions, location, mode = 'rw-------', '/private/key', 'file'
local content = 'test-token\n'
local reads = 0
local fakeIo = {}
fakeIo.open = function(path)
  assert(path == location)
  reads = reads + 1
  return {
    read = function()
      return content
    end,
    close = function() end,
  }
end
package.loaded['modules.notifications'] = {}
package.loaded['modules.ai_text.app_context'] = {
  styleInstruction = function()
    return ''
  end,
}
hs = {
  configdir = '/repo',
  fs = {
    pathToAbsolute = function(path)
      return path == '/repo' and path or location
    end,
    symlinkAttributes = function()
      return { permissions = permissions, mode = mode }
    end,
  },
  json = {
    encode = function(v)
      return v
    end,
    decode = function(v)
      return v
    end,
  },
  http = {
    asyncPost = function(url, payload, headers, callback)
      posted = { url = url, payload = payload, headers = headers, callback = callback }
    end,
  },
}
local client = assert(loadfile('modules/ai_text/lm_studio.lua', 't', setmetatable({ io = fakeIo }, { __index = _G })))()
local config = { lmStudioUrl = 'http://localhost:1234/v1/chat/completions', model = 'local-model' }
local function call(provider)
  posted, notice, finished, result = nil, nil, nil, nil
  client.call(config, { prompt = 'Translate into English.' }, 'Hola', function(text)
    result = text
  end, {
    provider = provider,
    active = function()
      return true
    end,
    finish = function(_, reason)
      finished = reason
    end,
    notifications = {
      info = function() end,
      error = function(key)
        notice = key
      end,
    },
  })
end
call('lmstudio')
assert(reads == 0 and posted.headers.Authorization == nil and posted.payload.model == 'local-model')
assert(posted.url == config.lmStudioUrl)
call('openrouter')
assert(posted.url == 'https://openrouter.ai/api/v1/chat/completions')
assert(posted.headers.Authorization == 'Bearer test-token')
assert(posted.payload.model == 'deepseek/deepseek-v4-flash')
assert(posted.payload.messages[2].content.text == 'Hola')
posted.callback(200, { choices = { { message = { content = 'Hello' } } } })
assert(result == 'Hello')
posted.callback(401, { error = { message = 'sensitive response' } })
assert(notice == 'ai_text.openrouter_error' and finished == notice)
content = ''
call('openrouter')
assert(posted == nil and notice == 'ai_text.openrouter_key')
content = 'test-token'
permissions = 'rw-r--r--'
call('openrouter')
assert(posted == nil and notice == 'ai_text.openrouter_key_permissions')
permissions, location = 'rw-------', '/repo/openrouter.key'
call('openrouter')
assert(posted == nil and notice == 'ai_text.openrouter_key_permissions')
location, mode = '/private/key', 'link'
call('openrouter')
assert(posted == nil and notice == 'ai_text.openrouter_key_permissions')
call('invalid')
assert(posted == nil and notice == 'ai_text.provider_invalid')
print('PASS: provider isolation, model, Bearer auth, missing/unsafe credentials and safe errors.')
