import assert from 'node:assert/strict';
import fs from 'node:fs';
import {backgroundColor,awsImage,iconColor} from '../streamdeck/com.vsdeck.jonyr.sdPlugin/aws-appearance.mjs';
import {PipelineController} from '../streamdeck/com.vsdeck.jonyr.sdPlugin/pipeline-controller.mjs';
import {SnapshotController} from '../streamdeck/com.vsdeck.jonyr.sdPlugin/snapshot-controller.mjs';
const svg=image=>Buffer.from(image.split(',')[1],'base64').toString();
assert.equal(backgroundColor(' #7c3aed '),'#7C3AED');
assert.equal(backgroundColor(''),'#2563EB');
for(const value of ['red','#123','#12345678','"/><script>','123456','#GGGGGG'])assert.throws(()=>backgroundColor(value));
assert.equal(iconColor(' #ffffff '),'#FFFFFF');assert.equal(iconColor(''),'#FFFFFF');assert.throws(()=>iconColor('white'));
for(const kind of ['pipeline','snapshot']){
 assert(svg(awsImage(kind,'idle','#FFFFFF','#FFFFFF')).includes('stroke="#FFFFFF"'));
 assert.equal(awsImage(kind,'idle','#2563EB','#FFFFFF'),`images/aws-${kind}-idle.svg`);
 assert.equal(awsImage(kind,'idle'),`images/aws-${kind}-idle.svg`);
 assert(svg(awsImage(kind,'idle','#FFFFFF')).includes('stroke="#FFFFFF"'));
 assert(svg(awsImage(kind,'idle','#000000')).includes('stroke="#FFFFFF"'));
 for(const state of ['busy','error']) assert.equal(awsImage(kind,state,'#7C3AED'),`images/aws-${kind}-${state}.svg`);
 const messages=[];
 const Controller=kind==='pipeline'?PipelineController:SnapshotController;
 let state='idle';
 const controller=new Controller({call:async()=>({state}),send:(...m)=>messages.push(m),schedule:()=>0,cancel:()=>{}});
 const settings={profile:'work',region:'us-east-1',pipeline:'backend',instance:'db',backgroundColor:'#7C3AED'};
 controller.appear('a',settings);controller.appear('b',{...settings,backgroundColor:'#FFFFFF'});
 await new Promise(resolve=>setImmediate(resolve));
 const latest=context=>messages.filter(m=>m[0]==='setImage'&&m[1]===context).at(-1)[2].image;
 assert(svg(latest('a')).includes('fill="#7C3AED"'));
 assert(svg(latest('b')).includes('fill="#FFFFFF"'));
 controller.appear('a',{...settings,backgroundColor:'#123456'});
 assert(svg(latest('a')).includes('fill="#123456"'),'editing the color must bypass the old image cache');
 assert(svg(latest('b')).includes('fill="#FFFFFF"'),'shared destination must not share appearance');
 controller.appear('b',{...settings,backgroundColor:'#FFFFFF',iconColor:'#FFFFFF'});
 assert(svg(latest('b')).includes('stroke="#FFFFFF"'),'foreground-only changes must refresh image');
 state='done';
 await controller.refresh([...controller.jobs.keys()][0]);
 assert(svg(latest('a')).includes('fill="#123456"'),'completed jobs must restore custom background');
 controller.appear('a',{...settings,backgroundColor:'#F7941E',iconColor:'#112233'});
 await new Promise(resolve=>setImmediate(resolve));
 assert(svg(latest('a')).includes('fill="#F7941E"'),'background edits must work after successful completion');
 assert(svg(latest('a')).includes('stroke="#112233"'),'icon edits must work after successful completion');
 state='busy';await controller.refresh([...controller.jobs.keys()][0]);
 assert.equal(latest('a'),`images/aws-${kind}-busy.svg`);
 state='done';await controller.refresh([...controller.jobs.keys()][0]);
 assert(svg(latest('a')).includes('fill="#F7941E"'));
 assert(!messages.some(m=>m[0]==='setTitle'),'native custom titles must not be overwritten');
}
const manifest=JSON.parse(fs.readFileSync('streamdeck/com.vsdeck.jonyr.sdPlugin/manifest.json'));
for(const action of manifest.Actions.filter(a=>/aws-(pipeline|snapshot)$/.test(a.UUID))){
 assert.equal(action.UserTitleEnabled,true);assert.equal(action.States[0].ShowTitle,true);
}
console.log('PASS: hex validation, per-key colors, contrast, feedback preservation, title support and image cache updates.');
// Property inspectors run in Chromium, so their complete import graph must stay browser-safe.
const visited=new Set();
function browserSafe(url){
 if(visited.has(url.href))return;visited.add(url.href);
 const source=fs.readFileSync(url,'utf8');
 for(const match of source.matchAll(/from\s+['"]([^'"]+)['"]/g)){
  assert(match[1].startsWith('./'),`Browser inspector cannot import ${match[1]}`);
  browserSafe(new URL(match[1],url));
 }
}
for(const kind of ['pipeline','snapshot'])browserSafe(new URL(`../streamdeck/com.vsdeck.jonyr.sdPlugin/${kind}-ui.mjs`,import.meta.url));
