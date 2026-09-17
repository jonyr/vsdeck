--- Verify discovery, playback lifetime and dispatch without audio hardware or network.
-- @script tests.soundboard_test
local errors, loaded, sounds, opened = {}, {}, {}
package.loaded['modules.notifications'] = {
  error = function(key)
    errors[#errors + 1] = key
  end,
}
package.loaded['modules.config.personal'] = { data = {} }
local filenames = { 'Vine boom.mp3', 'notes.txt', 'Huh cat.MP3', 'folder.wav' }
hs = {
  configdir = '/deck',
  fs = {
    attributes = function(path)
      if path == '/deck/sounds' or path:match('folder.wav$') then
        return 'directory'
      end
      if path:match('missing') then
        return nil
      end
      return 'file'
    end,
    dir = function()
      local index = 0
      return function()
        index = index + 1
        return filenames[index]
      end
    end,
  },
  urlevent = {
    openURL = function(url)
      opened = url
    end,
  },
  sound = {
    getByFile = function(path)
      loaded[#loaded + 1] = path
      if path == '/bad' then
        return nil
      end
      local sound = {}
      function sound:volume(value)
        self.level = value
      end
      function sound:loopSound(value)
        assert(value == false)
      end
      function sound:device(value)
        assert(value == nil)
      end
      function sound:setCallback(callback)
        self.callback = callback
      end
      function sound:play()
        return path ~= '/fail'
      end
      function sound:stop()
        self.stopped = true
      end
      sounds[#sounds + 1] = sound
      return sound
    end,
  },
}
local board = require('modules.soundboard')
local clips = board.clips({})
assert(#clips == 2 and clips[1].title == 'Huh cat' and clips[2].title == 'Vine boom')
assert(#board.clips({ directory = '/missing' }) == 0)
assert(#board.actions({ enabled = false }) == 0)
local config = { sounds = { { id = 'test', title = 'Test', path = '~/test.mp3' } }, volume = 0.4 }
local actions = board.actions(config)
assert(#actions == 3)
for _, action in ipairs(actions) do
  assert(action.requiresOrigin == false and action.category == 'Sonidos')
end
-- The real executor must play with no source window and no focus/timer APIs.
local executor = require('modules.deck.executor').new()
executor.run(actions[3], nil, 'replace')
assert(loaded[1] == os.getenv('HOME') .. '/test.mp3' and sounds[1].level == 0.4)
local oldCallback = sounds[1].callback
executor.run(actions[3], nil, 'copy')
assert(sounds[1].stopped and #sounds == 2)
oldCallback(true)
executor.run(actions[1], nil, 'copy')
assert(sounds[2].stopped)
board.stop()
assert(board.play({ path = '/ok', volume = 2 }, {}))
assert(sounds[3].level == 1)
assert(not board.play({ path = '/bad' }, {}))
assert(errors[#errors] == 'soundboard.load_error' and not sounds[3].stopped)
sounds[3].callback(true)
board.stop()
assert(not sounds[3].stopped)
assert(not board.play({ path = '/fail' }, {}))
assert(errors[#errors] == 'soundboard.play_error' and sounds[4].stopped)
assert(board.play({ path = '/ok', volume = -1 }, {}))
assert(sounds[5].level == 0)
sounds[5].callback(false)
assert(errors[#errors] == 'soundboard.play_error')
executor.run(actions[2], nil, 'copy')
assert(opened == 'https://tuna.voicemod.net/sounds/')
-- Registration must preserve the sound IDs in the shared Deck catalog.
package.loaded['modules.config.personal'].data.soundboard = config
package.loaded['modules.ai_text'] = {}
package.loaded['modules.ai_text.actions'] = { list = {} }
package.loaded['modules.deck.web_shortcuts'] = {}
local catalog = require('modules.deck.actions')
assert(catalog.byId['soundboard.clip.test'].requiresOrigin == false)
assert(catalog.byId['soundboard.stop'])
print('Soundboard discovery, playback, errors and shared dispatch tests passed')
