package.loaded['modules.config.personal']={data={notifications={backend='alert'}}}
local alerts, puts, callback, httpCallback, state, reply
local function reset()
 alerts={}; puts=0; callback=nil; httpCallback=nil
 state={state={on=true, reachable=true}}
 reply={{success={['/lights/6/state/on']=false}}}
 package.loaded['modules.hue']=nil
end
hs={alert={show=function(s) alerts[#alerts+1]=s end},
 timer={doAfter=function(_,fn) return {stop=function() end} end},
 task={new=function(_,cb, args)
   assert(args[1]=='find-generic-password')
   callback=cb; return {start=function() return true end}
 end},
 json={decode=function(s) return s end,encode=function(s) return s end},
 http={doAsyncRequest=function(_,method,body,_,cb)
   if method=='GET' then cb(200,state) else puts=puts+1; assert(body.on==false); cb(200,reply) end
 end}}
local config={bridge='192.168.1.100'}
local light={lightId='6',title='Luz',action='toggle'}
reset(); local m=require('modules.hue'); m.run(config,light); m.run(config,light)
assert(alerts[1]:find('en curso')); callback(0,'testkey\n'); assert(puts==1); assert(alerts[2]=='VSDeck\nLuz: apagada')
reset(); m=require('modules.hue'); m.run(config,light); callback(1,''); assert(puts==0); assert(alerts[1]:find('llavero'))
reset(); state.state.reachable=false; m=require('modules.hue'); m.run(config,light); callback(0,'testkey'); assert(puts==0); assert(alerts[1]:find('accesible'))
reset(); state={{error={type=1}}}; m=require('modules.hue'); m.run(config,light); callback(0,'testkey'); assert(puts==0); assert(alerts[1]:find('rechazó'))
reset(); reply={}; m=require('modules.hue'); m.run(config,light); callback(0,'testkey'); assert(alerts[1]:find('no confirmó'))
reset(); m=require('modules.hue'); m.run({bridge='invalid'},light); assert(callback==nil)
print('Hue tests passed')
