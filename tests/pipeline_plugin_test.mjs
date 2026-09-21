import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {pipelineSettings,fields} from '../streamdeck/com.vsdeck.jonyr.sdPlugin/pipeline-settings.mjs';
import {PipelineController} from '../streamdeck/com.vsdeck.jonyr.sdPlugin/pipeline-controller.mjs';
const settings={title:'Backup',profile:'work',region:'us-east-1',pipeline:'hotel-db'};
assert.deepEqual(pipelineSettings(settings),{...settings,backgroundColor:'#2563EB',iconColor:'#FFFFFF'});
for(const invalid of [{profile:'work;echo x'},{pipeline:'bad/name'},{pipeline:'bad name'},{region:'$(x)'},{pipeline:''}])assert.throws(()=>pipelineSettings({...settings,...invalid}));
const jobs=[],messages=[],timers=[];
let status={state:'idle'};
const controller=new PipelineController({call:async(method,id)=>{jobs.push({method,id});return method==='start'?{state:'busy'}:status;},send:(...args)=>messages.push(args),schedule:fn=>{timers.push(fn);return fn;},cancel:()=>{}});
controller.appear('key',settings);await new Promise(resolve=>setImmediate(resolve));
await controller.press('one','key',settings);
await controller.press('two','key',settings);
assert.equal(jobs.filter(job=>job.method==='start').length,1);
assert(messages.some(m=>m[2]?.image==='images/aws-pipeline-busy.svg'));
status={state:'done'};await timers.at(-1)();await new Promise(resolve=>setImmediate(resolve));
assert(messages.some(m=>m[2]?.image==='images/aws-pipeline-idle.svg'));
controller.disappear('key');
let attempts=0;
const uncertain=new PipelineController({call:async()=>{attempts++;throw new Error('disconnected');},send:()=>{},schedule:()=>0,cancel:()=>{}});
await uncertain.press('uncertain','key',settings);
assert.equal(attempts,1);
await uncertain.press('again','key',settings);
assert.equal(attempts,2, 'second press reads status rather than resubmitting creation');
assert.equal([...uncertain.jobs.values()][0].state,'unknown');
// Run the real inspector using a fake DOM and socket: saving uses inspector UUID,
// stale readback must not erase edits, and only matching readback confirms saving.
const elements=new Map();const get=id=>{if(!elements.has(id))elements.set(id,{value:'',textContent:'',addEventListener(name,fn){this[name]=fn;}});return elements.get(id);};
let socket;
class Socket{static OPEN=1;constructor(){socket=this;this.readyState=1;this.messages=[];}send(raw){this.messages.push(JSON.parse(raw));}}
const catalogs=JSON.parse(fs.readFileSync(new URL('../streamdeck/com.vsdeck.jonyr.sdPlugin/pipeline-locales.json',import.meta.url)));
const sandbox={window:{},document:{documentElement:{},getElementById:get},WebSocket:Socket,fields,pipelineSettings,fetch:async()=>({json:async()=>catalogs}),setTimeout:()=>1,clearTimeout:()=>{}};
vm.runInNewContext(fs.readFileSync(new URL('../streamdeck/com.vsdeck.jonyr.sdPlugin/pipeline-ui.mjs',import.meta.url),'utf8').replace(/^import .*;\n/,''),sandbox);
await sandbox.window.connectElgatoStreamDeckSocket('123','inspector','registerPropertyInspector',JSON.stringify({application:{language:'es'}}),JSON.stringify({context:'key',payload:{settings}}));
socket.onopen();get('pipeline').value='another-db';get('pipeline').input();get('backgroundColor').value='#7c3aed';get('backgroundColor').input();get('iconColor').value='#ffffff';get('iconColor').input();get('save').click();
const saved=socket.messages.at(-2);assert.equal(saved.payload.backgroundColor,'#7C3AED');assert.equal(saved.payload.iconColor,'#FFFFFF');assert.equal(saved.event,'setSettings');assert.equal(saved.context,'inspector');assert.equal(saved.payload.pipeline,'another-db');
socket.onmessage({data:JSON.stringify({event:'didReceiveSettings',context:'key',payload:{settings}})});
assert.equal(get('pipeline').value,'another-db');assert.equal(get('feedback').textContent,catalogs.es.saving);
socket.onmessage({data:JSON.stringify({event:'didReceiveSettings',context:'inspector',payload:{settings:saved.payload}})});
assert.equal(get('feedback').textContent,catalogs.es.saved);
const manifest=JSON.parse(fs.readFileSync(new URL('../streamdeck/com.vsdeck.jonyr.sdPlugin/manifest.json',import.meta.url)));
assert.equal(manifest.Actions.find(a=>a.UUID.endsWith('aws-pipeline')).SupportedInMultiActions,false);
console.log('Pipeline plugin tests passed');

for(const empty of ['', '   ', undefined]) {const normalized=pipelineSettings({...settings,region:empty,backgroundColor:empty,iconColor:empty});assert.equal(normalized.region,'us-east-1');assert.equal(normalized.backgroundColor,'#2563EB');assert.equal(normalized.iconColor,'#FFFFFF');}
