local dispatch, delayed, menu, escape, focused, runs
runs=0
local screen={frame=function() return {x=0,y=0,w=1200,h=900} end}
local target={id=function() return 1 end,screen=function() return screen end}
function target:focus() focused=self end
focused=target
local v={visible=false}
for _,name in ipairs({'windowStyle','windowTitle','level','allowTextEntry','allowNewWindows','allowNavigationGestures','deleteOnClose','closeOnEscape','frame','html'}) do v[name]=function(self) return self end end
function v:windowCallback(cb) self.callback=cb; return self end
function v:show() self.visible=true; return self end
function v:hide() self.visible=false; focused=target; return self end
function v:isVisible() return self.visible end
function v:hswindow() return {focus=function() focused='deck' end} end
function v:delete() self.deleted=true end
local function key(cb)
 return {enable=function(self) self.enabled=true end,disable=function(self) self.enabled=false end,delete=function() end,callback=cb}
end
hs={configdir='.',notify={new=function() return {send=function() end} end},drawing={windowLevels={floating=3}},
 json={encode=function() return '[]' end},screen={mainScreen=function() return screen end},
 window={focusedWindow=function() return focused end},
 hotkey={new=function(_,_,cb) escape=key(cb); return escape end,bind=function(_,_,cb) return key(cb) end},
 timer={doAfter=function(_,cb) delayed=cb; return {stop=function() end} end},
 webview={usercontent={new=function() return {setCallback=function(self,cb) dispatch=cb; return self end} end},new=function() return v end},
 menubar={new=function() menu={}; function menu:setTitle() return self end; function menu:setTooltip() return self end; function menu:setClickCallback(cb) self.click=cb; return self end; function menu:delete() self.deleted=true end; return menu end}}
package.loaded['modules.deck.actions']={list={},byId={
 free={requiresOrigin=false,run=function() runs=runs+1 end},
 origin={run=function(w) assert(w==target); runs=runs+1 end}}}
local deck=require('modules.deck')
deck.setupMenubar(); local first=menu; deck.setupMenubar(); assert(menu==first)
menu.click(); assert(v.visible and escape.enabled)
dispatch({body={type='run',id='free',mode='copy'}}); assert(v.visible and runs==1)
dispatch({body={type='run',id='origin',mode='replace'}}); assert(v.visible and focused==target); delayed(); assert(runs==2 and v.visible)
escape.callback(); assert(not v.visible and not escape.enabled)
menu.click(); assert(v.visible); dispatch({body={type='close'}}); assert(not v.visible)
menu.click(); assert(v.visible); menu.click(); assert(not v.visible)
deck.show(); v.callback('closing'); assert(not escape.enabled)
deck.stop(); assert(v.deleted and menu.deleted)
print('Deck tests passed')
