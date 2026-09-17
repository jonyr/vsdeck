local native, alerts
hs = {
  notify = { new = function(attributes)
    native[#native + 1] = attributes
    return { send = function(self) return self end }
  end },
  alert = { show = function(message, style, duration)
    alerts[#alerts + 1] = { message = message, style = style, duration = duration }
  end },
}
local function load(config)
  native, alerts = {}, {}
  package.loaded['modules.config.personal'] = { data = { language = 'en', notifications = config } }
  package.loaded['modules.i18n'] = nil
  package.loaded['modules.notifications'] = nil
  return require('modules.notifications')
end
local n = load({backend='notify'})
n.error('ai_text.error', {status=503})
assert(#native == 1 and #alerts == 0 and native[1].informativeText == 'LM Studio returned an error (503).')
n = load({backend='alert', title='Custom', duration=7, style={textSize=20}})
n.success('ai_text.copied')
assert(#native == 0 and #alerts == 1 and alerts[1].message == 'Custom\nResult copied')
assert(alerts[1].duration == 7 and alerts[1].style.textSize == 20)
n = load({backend='both'})
n.info('ai_text.processing'); assert(#native == 1 and #alerts == 1)
n = load({backend='notify', levels={info={enabled=false}, error={backend='alert', duration=9}}})
n.info('ai_text.processing'); assert(#native == 0 and #alerts == 0)
n.error('ai_text.empty_response'); assert(#native == 0 and #alerts == 1 and alerts[1].duration == 9)
n = load({enabled=false})
n.error('ai_text.empty_response'); assert(#native == 0 and #alerts == 0)
n = load(nil)
n.text('success','Done',{title='Task',final=true})
assert(#native == 1 and #alerts == 1 and native[1].withdrawAfter == 0 and alerts[1].duration == 10)
n = load({backend='alert'})
n.text('success','Done',{final=true}); assert(#native == 0 and #alerts == 1)
n = load({backend='alert',finalBackend='notify'})
n.text('success','Done',{final=true}); assert(#native == 1 and #alerts == 0)
n = load({backend='invalid',levels={error=true},duration=-1})
n.error('ai_text.empty_response'); assert(#native == 1 and #alerts == 0)
print('PASS: all channels, translation, level overrides, mute, custom appearance, task completion and invalid settings.')
