package.path='./?.lua;./?/init.lua;'..package.path
local attributes, alerts = {}, 0
hs={notify={new=function(a) attributes[#attributes+1]=a; return {send=function(self) return self end} end},alert={show=function(_,duration) assert(duration==10);alerts=alerts+1 end}}
local n=require('modules.tasks.notifications')
n.send('Progress','Waiting')
assert(attributes[1].withdrawAfter==5 and alerts==0)
n.send('Done','Available',true)
assert(attributes[2].withdrawAfter==0 and alerts==1)
n.send('Error','Wait failed',true)
assert(attributes[3].withdrawAfter==0 and alerts==2)
print('PASS: transient progress, persistent final outcomes and visible fallback.')
