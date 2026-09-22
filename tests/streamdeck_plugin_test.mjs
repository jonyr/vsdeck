import assert from 'node:assert/strict';
import { Controller } from '../streamdeck/com.vsdeck.jonyr.sdPlugin/controller.mjs';
const sent = [], scheduled = [], calls = [];
let answer = { state: 'idle' };
const controller = new Controller({
  send: (...args) => sent.push(args),
  call: async (...args) => { calls.push(args); if (answer instanceof Error) throw answer; return typeof answer === 'function' ? answer() : answer; },
  schedule: (fn, delay) => { const timer = { fn, delay }; scheduled.push(timer); return timer; },
  cancel: timer => { if (timer) timer.cancelled = true; },
});
const tick = async delay => {
  const task = scheduled.find(task => !task.cancelled && task.delay === delay);
  assert.ok(task); task.cancelled = true; await task.fn();
};
await controller.appear('first');
assert.equal(controller.state, 'idle');
let release;
answer = () => new Promise(resolve => { release = resolve; });
const press = controller.press('one');
assert.equal(controller.state, 'busy');
await controller.press('two');
assert.equal(calls.filter(([name]) => name === 'start').length, 1);
release({ state: 'busy', labels: { busy: 'Traduciendo…' } }); await press;
assert.ok(sent.some(([event, , data]) => event === 'setImage' && data.image === 'images/translate-busy.svg'));
controller.disappear('first');
await controller.appear('second');
assert.equal(controller.state, 'busy');
answer = { state: 'done' }; await tick(500);
assert.equal(controller.state, 'idle');
assert.ok(sent.some(([event, context, data]) => event === 'setImage' && context === 'second' && data.image === 'images/translate-idle.svg'));
answer = new Error('Hammerspoon unavailable'); await controller.press('three');
assert.equal(controller.state, 'error'); await tick(2000); assert.equal(controller.state, 'idle');
answer = { state: 'error' }; await controller.press('four');
assert.equal(controller.state, 'error');
answer = { state: 'busy' }; await controller.press('five');
assert.equal(controller.state, 'busy');
assert.ok(scheduled.filter(t => t.delay === 2000).every(t => t.cancelled));
answer = { state: 'done' }; await tick(500);
console.log('PASS: busy feedback, duplicate prevention, page changes, reset and bridge failures.');

// An old appearance query must not erase a newer completed request's error state.
let resolveAppearance;
answer = () => new Promise(resolve => { resolveAppearance = resolve; });
const appearance = controller.appear('third');
answer = { state: 'error' };
await controller.press('six');
resolveAppearance({ state: 'idle' });
await appearance;
assert.equal(controller.state, 'error');

// Real subprocess regression: a CLI reading piped stdin must receive EOF.
const { runJsonCommand } = await import('../streamdeck/com.vsdeck.jonyr.sdPlugin/bridge.mjs');
const status = await runJsonCommand(process.execPath, ['-e', `
  process.stdin.resume();
  process.stdin.on('end', () => process.stdout.write(JSON.stringify({state:'done'})));
`], 2000);
assert.equal(status.state, 'done');
await assert.rejects(runJsonCommand(process.execPath, ['-e', "process.stdout.write('bad json')"]), /Invalid bridge response/);
await assert.rejects(runJsonCommand(process.execPath, ['-e', 'process.exit(3)']));
await assert.rejects(runJsonCommand(process.execPath, ['-e', 'setInterval(() => {}, 1000)'], 100));
console.log('PASS: subprocess EOF, invalid JSON, command failure and timeout.');

// Both actions share a lock, but only the action being executed changes color.
answer = { state: 'idle', action: 'translate' };
await controller.appear('correction', 'correct');
answer = { state: 'busy', action: 'correct' };
await controller.press('correct-one', 'correct');
const starts = calls.filter(([method]) => method === 'start').length;
await controller.press('blocked-translation', 'translate');
assert.equal(calls.filter(([method]) => method === 'start').length, starts);
assert.ok(sent.some(([event, context, data]) => event === 'setImage' && context === 'correction' && data.image === 'images/correct-busy.svg'));
assert.equal(sent.filter(([event, context]) => event === 'setImage' && context === 'second').at(-1)[2].image, 'images/translate-idle.svg');
answer = { state: 'done', action: 'correct' }; await tick(500);
assert.equal(controller.state, 'idle');
assert.equal(sent.filter(([event, context]) => event === 'setImage' && context === 'correction').at(-1)[2].image, 'images/correct-idle.svg');
assert.ok(!sent.some(([event]) => event === 'setTitle'), 'Text actions must preserve native titles');

// Discord reports actual presence and does not predict state from a successful click.
const { PresenceController } = await import('../streamdeck/com.vsdeck.jonyr.sdPlugin/presence-controller.mjs');
const presenceEvents = [];
const presenceTimers = new Map();
let presenceAnswer = {state:'idle', presence:'online', id:''};
let presenceStarts = 0;
const presenceController = new PresenceController({
  call: async method => { if (method === 'start') presenceStarts++; return presenceAnswer; },
  send: (...args) => presenceEvents.push(args),
  schedule: (fn, delay) => { const key = {}; presenceTimers.set(key, {fn, delay}); return key; },
  cancel: key => presenceTimers.delete(key),
});
presenceController.appear('lunch');
await new Promise(resolve => setImmediate(resolve));
assert.equal(presenceController.state, 'online');
presenceAnswer = {state:'busy', presence:'unknown', id:'lunch-1'};
await presenceController.press('lunch-1');
await presenceController.press('duplicate');
assert.equal(presenceStarts, 1);
assert.equal(presenceController.state, 'busy');
presenceAnswer = {state:'done', presence:'away', id:'lunch-1'};
await presenceController.refresh();
assert.equal(presenceController.state, 'away');
presenceAnswer = {state:'error', presence:'away', id:'lunch-2'};
await presenceController.press('lunch-2');
assert.equal(presenceController.state, 'error');
await presenceController.refresh();
assert.equal(presenceController.state, 'away');
presenceAnswer = {state:'done', presence:'online', id:'lunch-2'};
await presenceController.refresh();
assert.equal(presenceController.state, 'online');
presenceAnswer = {state:'done', presence:'unknown', id:'lunch-2'};
await presenceController.refresh();
assert.equal(presenceController.state, 'unknown');
presenceController.call = async () => {throw new Error('Unavailable');};
await presenceController.refresh();
assert.equal(presenceController.state, 'unknown');
assert.ok(!presenceEvents.some(([event]) => event === 'setTitle'), 'Presence actions must preserve native titles');
presenceController.disappear('lunch');
assert.equal(presenceTimers.size, 0);
console.log('PASS: Discord presence colors, busy lock, observed state, errors and polling cleanup.');

const {presenceSettings, defaults, luaJson} = await import('../streamdeck/com.vsdeck.jonyr.sdPlugin/presence-settings.mjs');
assert.deepEqual(presenceSettings(), defaults);
assert.equal(presenceSettings({emoji:':coffee:'}).emoji, 'coffee');
for (const duration of ['30m','1h','4h','24h','never']) assert.equal(presenceSettings({duration}).duration,duration);
assert.throws(() => presenceSettings({duration:'2h'}));
assert.throws(() => presenceSettings({message:'a\nb'}));
assert.throws(() => presenceSettings({message:'x'.repeat(129)}));
assert.throws(() => presenceSettings({emoji:'🥩'}));
const malicious = {message: `'); error("injected"); -- 🥩 \\`, emoji:'', duration:'never'};
const {execFileSync} = await import('node:child_process');
assert.equal(execFileSync('lua',['-e',`io.write(${luaJson(malicious)})`],{encoding:'utf8'}),JSON.stringify(malicious));
let sentSettings;
presenceController.call = async (method,id,settings) => {sentSettings=settings;return {id,state:'done',presence:'online'};};
presenceController.updateSettings('lunch',{message:'Break',emoji:'coffee',duration:'30m'});
await presenceController.press('with-settings','lunch');
assert.deepEqual(sentSettings,{message:'Break',emoji:'coffee',duration:'30m',mode:'lunch'});

// Execute the actual inspector with a fake DOM and WebSocket, never a live app.
const fs = await import('node:fs');
const vm = await import('node:vm');
const elements = new Map();
const getElement = id => {
  if (!elements.has(id)) elements.set(id,{value:'',textContent:'',listeners:{},children:[],addEventListener(event,fn){this.listeners[event]=fn;},append(child){this.children.push(child);}});
  return elements.get(id);
};
let inspectorSocket;
class InspectorSocket {
  static OPEN = 1;
  constructor(){this.readyState=1;this.messages=[];inspectorSocket=this;}
  send(data){this.messages.push(JSON.parse(data));}
}
const sandbox={window:{},document:{documentElement:{},getElementById:getElement,createElement:()=>({listeners:{},addEventListener(event,fn){this.listeners[event]=fn;}})},WebSocket:InspectorSocket,presenceSettings,defaults,setTimeout,clearTimeout,fetch:async()=>({json:async()=>JSON.parse(fs.readFileSync(new URL('../streamdeck/com.vsdeck.jonyr.sdPlugin/presence-locales.json',import.meta.url),'utf8'))})};
vm.runInNewContext(fs.readFileSync(new URL('../streamdeck/com.vsdeck.jonyr.sdPlugin/presence-ui.mjs',import.meta.url),'utf8').replace(/^import .*;\n/,''),sandbox);
await sandbox.window.connectElgatoStreamDeckSocket('1234','inspector-id','registerPropertyInspector',JSON.stringify({application:{language:'es'}}),JSON.stringify({action:'com.vsdeck.jonyr.discord-lunch',context:'key-instance',payload:{settings:{message:'Meeting',emoji:'coffee',duration:'4h'}}}));
inspectorSocket.onopen();
assert.equal(getElement('message').value,'Meeting');
assert.equal(getElement('duration').children.length,5);
assert.deepEqual(getElement('presenceDurationOptions').children.map(v=>v.value),['15m','1h','8h','24h','3d','forever']);
getElement('presenceDurationOptions').children[2].listeners.click();
assert.equal(getElement('presenceDuration').value,'8h');
assert.equal(getElement('presenceDuration').textContent,'8 horas');
assert.equal(getElement('presenceDurationOptions').hidden,true);
assert.equal(getElement('emojiLabel').textContent,'Emoji del estado');
getElement('message').value='Almorzando';getElement('message').listeners.input();
assert.equal(getElement('feedback').textContent,'Cambios sin guardar');
getElement('save').listeners.click();
const saved = inspectorSocket.messages.at(-2);
assert.equal(saved.event,'setSettings');
assert.equal(saved.context,'inspector-id');
assert.equal(saved.payload.message,'Almorzando');
assert.equal(saved.payload.presenceDuration,'8h');
assert.equal(inspectorSocket.messages.at(-1).event,'getSettings');
assert.equal(getElement('feedback').textContent,'Guardando…');
// A stale read must not report success or erase edits.
inspectorSocket.onmessage({data:JSON.stringify({event:'didReceiveSettings',context:'key-instance',payload:{settings:{message:'Old'}}})});
assert.equal(getElement('feedback').textContent,'Guardando…');
inspectorSocket.onmessage({data:JSON.stringify({event:'didReceiveSettings',context:'key-instance',payload:{settings:saved.payload}})});
assert.equal(getElement('feedback').textContent,'Guardado');
const savedCount=inspectorSocket.messages.length;
getElement('emoji').value='bad emoji';getElement('emoji').listeners.input();getElement('save').listeners.click();
assert.equal(inspectorSocket.messages.length,savedCount);
assert.ok(getElement('feedback').textContent.includes('nombre'));
// Reopening loads the persisted values, including the normalized emoji.
await sandbox.window.connectElgatoStreamDeckSocket('1234','inspector-id','registerPropertyInspector',JSON.stringify({application:{language:'es'}}),JSON.stringify({action:'com.vsdeck.jonyr.discord-lunch',context:'key-instance',payload:{settings:saved.payload}}));
assert.equal(getElement('message').value,'Almorzando');
assert.equal(getElement('emoji').value,'coffee');
assert.equal(getElement('duration').value,'4h');
for(const target of ['online','away','dnd','invisible']) {
 for(const presenceDuration of ['15m','1h','8h','24h','3d','forever']) assert.equal(presenceSettings({mode:'presence',target,presenceDuration}).target,target);
}
assert.throws(()=>presenceSettings({target:'wrong'}));
assert.throws(()=>presenceSettings({presenceDuration:'30m'}));
// Repeated state polls must not rewrite the title/image while editing settings.
const events=[];
const stable=new PresenceController({call:async()=>({state:'idle',presence:'dnd'}),send:(...args)=>events.push(args),schedule:()=>1,cancel:()=>{}});
stable.appear('presence-key',{target:'dnd'},'presence');
await new Promise(resolve=>setImmediate(resolve));
const eventCount=events.length;
await stable.refresh();await stable.refresh();
assert.equal(events.length,eventCount);
assert.ok(events.some(([event,,payload])=>event==='setImage' && payload.image==='images/discord-presence-dnd.svg'));
console.log('PASS: per-key settings acknowledgement, stale-read protection, persistence, localization, validation and stable rendering.');

// Route the real plugin events for hidden Multi Action Switch children.
const {handlePresenceEvent} = await import('../streamdeck/com.vsdeck.jonyr.sdPlugin/presence-events.mjs');
const multiCalls=[], multiImages=[], multiTimers=new Map();
let multiAnswer={id:'m1',state:'busy',presence:'unknown'};
const multi=new PresenceController({call:async(...args)=>{multiCalls.push(args);return multiAnswer;},send:(...args)=>multiImages.push(args),schedule:(fn,delay)=>{const id={};multiTimers.set(id,{fn,delay});return id;},cancel:id=>multiTimers.delete(id)});
const multiEvent=(event,context,target)=>({event,context,action:'com.vsdeck.jonyr.discord-presence',payload:{isInMultiAction:true,settings:{target,presenceDuration:'1h',mode:'lunch'}}});
handlePresenceEvent(multi,multiEvent('willAppear','side-one','dnd'),()=> 'm1');
handlePresenceEvent(multi,multiEvent('keyDown','side-one','dnd'),()=> 'm1');
await new Promise(resolve=>setImmediate(resolve));
assert.equal(multiCalls[0][2].mode,'presence');
assert.equal(multiCalls[0][2].target,'dnd');
assert.equal(multiImages.length,0);
assert.equal(multiTimers.size,1,'Busy hidden actions must continue polling');
handlePresenceEvent(multi,multiEvent('keyDown','side-two','online'),()=> 'm2');
await new Promise(resolve=>setImmediate(resolve));
assert.equal(multiCalls.filter(([method])=>method==='start').length,1);
multiAnswer={id:'m1',state:'done',presence:'dnd'};
await multi.refresh();
assert.equal(multiTimers.size,0,'Hidden actions stop polling after completion');
handlePresenceEvent(multi,multiEvent('keyDown','side-two','online'),()=> 'm2');
await new Promise(resolve=>setImmediate(resolve));
assert.equal(multiCalls.at(-1)[2].target,'online');
assert.equal(multiCalls.at(-1)[2].mode,'presence');
assert.equal(multiImages.length,0);
// A read in progress must not swallow a physical key press.
let releaseRead;
const duringRead=new PresenceController({call:method=>method==='status'?new Promise(resolve=>{releaseRead=resolve;}):Promise.resolve({state:'done',presence:'online'}),send:()=>{},schedule:()=>1,cancel:()=>{}});
const read=duringRead.refresh();
let executed=false;
const pressed=duringRead.press('after-read','hidden',{mode:'presence',settings:{target:'online'}}).then(()=>{executed=true;});
releaseRead({state:'idle',presence:'away'});
await read;await pressed;
assert.equal(executed,true);
assert.equal(duringRead.state,'online');
const manifest=JSON.parse(fs.readFileSync(new URL('../streamdeck/com.vsdeck.jonyr.sdPlugin/manifest.json',import.meta.url),'utf8'));
assert.deepEqual(manifest.Actions.filter(a=>a.SupportedInMultiActions).map(a=>a.UUID),['com.vsdeck.jonyr.discord-presence']);
console.log('PASS: Multi Action Switch routing, independent targets, hidden lifecycle, no parent icon writes and polling race.');

const {textSettings, fields: textFields, languages} = await import('../streamdeck/com.vsdeck.jonyr.sdPlugin/text-settings.mjs');
const {awsImage} = await import('../streamdeck/com.vsdeck.jonyr.sdPlugin/aws-appearance.mjs');
assert.equal(textSettings().targetLanguage,'en');
assert.throws(()=>textSettings({targetLanguage:'injected'}));
const rendered=Buffer.from(awsImage('translate','idle','#123456','#ABCDEF').split(',')[1],'base64').toString();
assert.ok(rendered.includes('fill="#123456"')&&rendered.includes('stroke="#ABCDEF"'));
let textArgs;
const textEvents=[];
const textController=new Controller({call:async(...args)=>{textArgs=args;return {state:'done'};},send:(...args)=>textEvents.push(args)});
await textController.appear('one','translate',{backgroundColor:'#123456',iconColor:'#ABCDEF'});
await textController.appear('two','correct');
await textController.press('language','translate',{targetLanguage:'fr'});
assert.equal(textArgs[3].targetLanguage,'fr');
assert.equal(textEvents.filter(([event,ctx])=>event==='setImage'&&ctx==='two').at(-1)[2].image,'images/correct-idle.svg');
const textSandbox={...sandbox,window:{},fields:textFields,textSettings,languages,fetch:async()=>({json:async()=>JSON.parse(fs.readFileSync(new URL('../streamdeck/com.vsdeck.jonyr.sdPlugin/text-locales.json',import.meta.url),'utf8'))})};
vm.runInNewContext(fs.readFileSync(new URL('../streamdeck/com.vsdeck.jonyr.sdPlugin/text-ui.mjs',import.meta.url),'utf8').replace(/^import .*;\n/,''),textSandbox);
await textSandbox.window.connectElgatoStreamDeckSocket('1234','text-panel','registerPropertyInspector',JSON.stringify({application:{language:'es'}}),JSON.stringify({action:'com.vsdeck.jonyr.english',context:'text-key',payload:{settings:{targetLanguage:'fr'}}}));
inspectorSocket.onopen();
assert.equal(getElement('targetLanguage').value,'fr');
getElement('targetLanguage').value='pt';getElement('targetLanguage').listeners.input();
getElement('backgroundColor').value='#123456';
getElement('iconColor').value='#abcdef';
getElement('save').listeners.click();
const savedText=inspectorSocket.messages.find(m=>m.event==='setSettings').payload;
assert.equal(savedText.targetLanguage,'pt');assert.equal(savedText.iconColor,'#ABCDEF');
inspectorSocket.onmessage({data:JSON.stringify({event:'didReceiveSettings',context:'text-key',payload:{settings:savedText}})});
assert.equal(getElement('feedback').textContent,'Cambios guardados.');
console.log('PASS: text inspector saves language and colors, independent images, and model settings routing.');

// Every existing and future action must support user-managed native titles.
for (const action of manifest.Actions) {
  assert.equal(action.UserTitleEnabled, true, action.UUID);
  for (const state of action.States) assert.equal(state.ShowTitle, true, action.UUID);
}

// Two copies of Translate must never share progress or errors, even across pages.
let isolatedStatus={state:'idle'}, isolateRelease;
const isolatedEvents=[], isolatedTimers=[];
const isolated=new Controller({
 call:async method=>method==='start'?new Promise(resolve=>{isolateRelease=resolve;}):isolatedStatus,
 send:(...event)=>isolatedEvents.push(event),schedule:fn=>{isolatedTimers.push(fn);return fn;},cancel:()=>{}
});
await isolated.appear('english','translate');
await isolated.appear('french','translate',{targetLanguage:'fr'});
const lastImage=ctx=>isolatedEvents.filter(([event,context])=>event==='setImage'&&context===ctx).at(-1)[2].image;
const isolatedPress=isolated.press('isolated','translate',{},'english');
assert.equal(lastImage('english'),'images/translate-busy.svg');
assert.equal(lastImage('french'),'images/translate-idle.svg');
isolated.disappear('english');
await isolated.appear('french','translate',{targetLanguage:'fr'});
assert.equal(lastImage('french'),'images/translate-idle.svg');
await isolated.appear('english','translate');
assert.equal(lastImage('english'),'images/translate-busy.svg');
isolateRelease({state:'error',id:'isolated'});await isolatedPress;
assert.equal(lastImage('english'),'images/translate-error.svg');
assert.equal(lastImage('french'),'images/translate-idle.svg');
isolatedTimers.at(-1)();
assert.equal(lastImage('english'),'images/translate-idle.svg');
const foreign=isolated.press('new-request','translate',{},'french');
isolateRelease({state:'busy',id:'another-client'});await foreign;
assert.equal(lastImage('french'),'images/translate-idle.svg');
console.log('PASS: per-key text feedback, page restoration and foreign-job isolation.');

// Structure is a real text action with the same per-key customization and native title contract.
const structureAction=manifest.Actions.find(a=>a.UUID==='com.vsdeck.jonyr.structure');
assert.equal(structureAction.Name,'Structure');
assert.equal(structureAction.PropertyInspectorPath,'text.html');
const structureSvg=Buffer.from(awsImage('structure','idle','#123456','#ABCDEF').split(',')[1],'base64').toString();
assert.ok(structureSvg.includes('fill="#123456"')&&structureSvg.includes('stroke="#ABCDEF"'));
for (const state of ['idle','busy','error']) assert.ok(fs.existsSync(new URL(`../streamdeck/com.vsdeck.jonyr.sdPlugin/images/structure-${state}.svg`,import.meta.url)));
await textController.appear('structure','structure');
await textController.press('structure-run','structure',{},'structure');
assert.equal(textArgs[2],'structure');
await textSandbox.window.connectElgatoStreamDeckSocket('1234','structure-panel','registerPropertyInspector',JSON.stringify({application:{language:'es'}}),JSON.stringify({action:structureAction.UUID,context:'structure-key',payload:{settings:{}}}));
assert.equal(getElement('targetLanguage').hidden,true);
assert.ok(getElement('hint').textContent.includes('texto plano'));
assert.equal(getElement('outputFormat').hidden,false);
assert.equal(getElement('outputFormat').value,'plain');
getElement('outputFormat').value='markdown';getElement('outputFormat').listeners.input();
getElement('save').listeners.click();
const formatSaved=inspectorSocket.messages.find(m=>m.event==='setSettings').payload;
assert.equal(formatSaved.outputFormat,'markdown');
inspectorSocket.onmessage({data:JSON.stringify({event:'didReceiveSettings',context:'structure-key',payload:{settings:formatSaved}})});
assert.equal(getElement('feedback').textContent,'Cambios guardados.');
assert.equal(getElement('outputFormat').value,'markdown');
assert.equal(textSettings().outputFormat,'plain');
assert.throws(()=>textSettings({outputFormat:'html'}));
console.log('PASS: Structure manifest, icon colors, command routing and property inspector.');

const emailAction=manifest.Actions.find(a=>a.UUID==='com.vsdeck.jonyr.email');
assert.equal(emailAction.Name,'Email');
assert.equal(emailAction.UserTitleEnabled,true);
assert.equal(emailAction.States[0].ShowTitle,true);
const emailSvg=Buffer.from(awsImage('email','idle','#123456','#ABCDEF').split(',')[1],'base64').toString();
assert.ok(emailSvg.includes('fill="#123456"')&&emailSvg.includes('stroke="#ABCDEF"'));
await textController.appear('email','email');
await textController.press('email-run','email',{targetLanguage:'es'},'email');
assert.equal(textArgs[2],'email');assert.equal(textArgs[3].targetLanguage,'es');
await textSandbox.window.connectElgatoStreamDeckSocket('1234','email-panel','registerPropertyInspector',JSON.stringify({application:{language:'es'}}),JSON.stringify({action:emailAction.UUID,context:'email-key',payload:{settings:{targetLanguage:'fr'}}}));
assert.equal(getElement('targetLanguage').hidden,false);
assert.equal(getElement('outputFormat').hidden,true);
assert.equal(getElement('targetLanguage').value,'fr');
getElement('targetLanguage').value='es';getElement('targetLanguage').listeners.input();
getElement('save').listeners.click();
const emailSaved=inspectorSocket.messages.find(m=>m.event==='setSettings').payload;
assert.equal(emailSaved.targetLanguage,'es');
inspectorSocket.onmessage({data:JSON.stringify({event:'didReceiveSettings',context:'email-key',payload:{settings:emailSaved}})});
assert.equal(getElement('feedback').textContent,'Cambios guardados.');
console.log('PASS: Email title, envelope colors, target language routing and saved inspector settings.');

assert.equal(manifest.UUID,"com.vsdeck.jonyr");
for (const action of manifest.Actions) assert.ok(action.UUID.startsWith(manifest.UUID+"."));

// Configured colors are per key; global polling never repaints unrelated keys.
const isolatedPresenceEvents=[];
let isolatedPresenceAnswer={id:'',state:'idle',presence:'online'};
const isolatedPresence=new PresenceController({call:async()=>isolatedPresenceAnswer,send:(...v)=>isolatedPresenceEvents.push(v),schedule:()=>1,cancel:()=>{}});
for(const [key,target] of [['idle','away'],['hidden','invisible'],['dnd','dnd'],['online','online']]) isolatedPresence.appear(key,{target},'presence');
await new Promise(resolve=>setImmediate(resolve));
const imageOf=key=>isolatedPresenceEvents.filter(v=>v[1]===key).at(-1)[2].image;
assert.equal(imageOf('idle'),'images/discord-presence-away.svg');
assert.equal(imageOf('hidden'),'images/discord-presence-invisible.svg');
assert.equal(imageOf('dnd'),'images/discord-presence-dnd.svg');
assert.equal(imageOf('online'),'images/discord-presence-online.svg');
const beforeOthers=isolatedPresenceEvents.filter(v=>v[1]!=='dnd').length;
isolatedPresenceAnswer={id:'own',state:'busy',presence:'unknown'};
await isolatedPresence.press('own','dnd');
assert.equal(imageOf('dnd'),'images/discord-presence-busy.svg');
assert.equal(isolatedPresenceEvents.filter(v=>v[1]!=='dnd').length,beforeOthers);
isolatedPresenceAnswer={id:'own',state:'error',presence:'online'};
await isolatedPresence.refresh();
assert.equal(imageOf('dnd'),'images/discord-presence-error.svg');
await isolatedPresence.refresh();
assert.equal(imageOf('dnd'),'images/discord-presence-dnd.svg');
isolatedPresence.updateSettings('dnd',{target:'dnd',backgroundColor:'#123456',iconColor:'#ABCDEF'});
const customSvg=Buffer.from(imageOf('dnd').split(',')[1],'base64').toString();
assert.ok(customSvg.includes('fill="#123456"')&&customSvg.includes('stroke="#ABCDEF"'));
isolatedPresence.updateSettings('dnd',{target:'online',backgroundColor:''});
assert.equal(imageOf('dnd'),'images/discord-presence-online.svg');
assert.throws(()=>presenceSettings({backgroundColor:'red'}));
assert.throws(()=>presenceSettings({iconColor:'<svg>'}));
assert.equal(presenceSettings({backgroundColor:' #aabbcc '}).backgroundColor,'#AABBCC');
console.log('PASS: automatic per-target colors, custom background/icon, isolated busy/error and restoration.');
