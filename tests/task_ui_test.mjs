import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const html=fs.readFileSync('modules/tasks/ui.html','utf8');
const script=html.match(/<script>([\s\S]*?)<\/script>/)[1];
for(const scenario of ['center','confirm','toast','history']) {
 const kind=scenario==='history'?'center':scenario;
 const elements=new Map();
 const element=id=>{if(!elements.has(id))elements.set(id,{innerHTML:'',dataset:{}});return elements.get(id)};
 const events={}, messages=[];
 const job={uid:'7',state:'busy',phase:'confirm',title:'<img src=x onerror=alert(1)>',instance:'hotel-db',name:'a"/><script>bad()</script>',profile:'work',region:'us-east-1',account:'123456789012',origin:'physical',reason:'<bad>',time:'14:30',kind:'pipeline',executionId:'execution-1',executionStatus:'InProgress',artifacts:[{name:'Backend',revisionId:'abc',revisionSummary:'<script>bad()</script>',revisionUrl:'https://example.com/abc'},{name:'K8S',revisionId:'def',revisionSummary:'Update',revisionUrl:'javascript:alert(1)'}]};
 if(scenario==='history')job.state='done';
 const data={kind,tab:scenario==='history'?'history':'attention',selected:'7',strings:{'task_ui.close':'Cerrar'},job,jobs:[job]};
 const document={documentElement:{},body:{append:e=>elements.set('close',e)},getElementById:element,querySelectorAll:()=>[],createElement:()=>({}),addEventListener:(event,fn)=>events[event]=fn};
 vm.runInNewContext(script.replace('__TASK_DATA__',JSON.stringify(data)),{document,window:{webkit:{messageHandlers:{['taskUI'+kind]:{postMessage:b=>messages.push(b)}}}}});
 assert(!element('app').innerHTML.includes('<script>bad()'));
 assert(!element('app').innerHTML.includes('<img src=x'));
 if(kind==='center'){assert(element('app').innerHTML.includes('Backend'));assert(element('app').innerHTML.includes('K8S'));assert(element('app').innerHTML.includes('&lt;script&gt;'));assert(!element('app').innerHTML.includes('href="javascript:'));}
 if(scenario==='history'){element('clearHistory').onclick();assert.equal(messages.at(-1).action,'clearHistory');}
 if(kind==='confirm'){
  const event={target:{}};element('create').onclick(event);assert.equal(event.target.disabled,true);
  assert.deepEqual(JSON.parse(JSON.stringify(messages[0])),{action:'confirm',id:'7'});
 }
 if(kind!=='toast'){
  events.keydown({key:'Escape',preventDefault(){}});
  assert.equal(messages.at(-1).action,kind==='confirm'?'cancel':'dismiss');
  elements.get('close').onclick();assert.equal(messages.at(-1).action,kind==='confirm'?'cancel':'dismiss');
 } else {
  element('open').onclick();assert.equal(messages.at(-1).id,'7');
  element('dismiss').onclick();assert.equal(messages.at(-1).action,'dismiss');
 }
}
console.log('PASS: real task HTML rendering, escaping, confirmation, Escape, close and toast routing.');
