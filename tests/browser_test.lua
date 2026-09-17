package.path='./?.lua;./?/init.lua;'..package.path
local launches={}
local exists=true
hs={application={pathForBundleID=function(id) return '/Applications/'..id..'.app' end},fs={attributes=function() return exists and 'directory' or nil end},task={new=function(executable,callback,args)
 launches[#launches+1]={executable=executable,args=args}
 return {start=function() return true end}
end}}
package.loaded['modules.deck.browsers.safari']={open=function(request, spec)
 if request.profile then assert(request.profile=='Work'); return true end
 local args={'-b', spec.bundle}; for _,url in ipairs(request.urls) do args[#args+1]=url end
 return require('modules.deck.browsers.process').launch('/usr/bin/open', args)
end}
local b=require('modules.deck.browser')
assert(b.open({browser='chrome', profileDirectory='Profile 2',urls={'https://example.com','https://example.org/?x=1&y=2'}}))
assert(launches[1].args[2]=='--profile-directory=Profile 2')
assert(#launches[1].args==4)
assert(b.open({browser='brave',urls={'https://example.com'}}))
assert(#launches[2].args==2 and launches[2].args[1]=='--new-window')
assert(b.open({urls={'https://example.com','https://example.org'}}))
assert(launches[3].executable=='/usr/bin/open' and launches[3].args[2]=='com.apple.Safari')
assert(b.open({browser='safari',profile='Work',urls={'https://example.com'}}))
local n=#launches
assert(not b.open({browser='chrome',profileDirectory='../secret',urls={'https://example.com'}}))
assert(not b.open({browser='chrome',profile='Usuario',urls={'https://example.com'}}))
assert(not b.open({browser='firefox',urls={'https://example.com'}}))
assert(not b.open({browser='brave',urls={'--bad-option'}}))
exists=false
assert(not b.open({browser='chrome',profileDirectory='Missing',urls={'https://example.com'}}))
assert(#launches==n)
print('PASS: Chrome explicit profile, Brave default, Safari explicit/default, URL order, invalid browser/profile/URL, missing profile.')

assert(not b.open({browser='safari', profileDirectory='Default', urls={'https://example.com'}}))
assert(not b.open({browser='chrome', profileDirectory='   ', urls={'https://example.com'}}))
assert(not b.open({browser={}, urls={'https://example.com'}}))
-- Adding a Chromium variant is data-only; the dispatcher is unchanged.
local registry=require('modules.deck.browsers.registry')
registry.test_variant={label='Test',adapter='modules.deck.browsers.chromium',bundle='org.test',executable='Test',data='Test',profileField='profileDirectory'}
assert(b.open({browser='test_variant',urls={'https://example.com'}}))
assert(launches[#launches].executable=='/Applications/org.test.app/Contents/MacOS/Test')
-- Process launch failures are returned, not reported as success.
hs.task.new=function() return nil end
assert(not b.open({browser='chrome',urls={'https://example.com'}}))
hs.task.new=function() return {start=function() return false end} end
assert(not b.open({browser='brave',urls={'https://example.com'}}))
print('PASS: adapter extension, cross-browser field rejection and process launch failures.')
