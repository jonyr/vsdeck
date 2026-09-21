import {fields, snapshotSettings} from './snapshot-settings.mjs';
const $ = id => document.getElementById(id);
let socket, context, actionContext, settings = {}, strings = {}, pending, timer, dirty = false;
const render = () => fields.forEach(key => { $(key).value = settings[key] || ({backgroundColor:'#2563EB',iconColor:'#FFFFFF',region:'us-east-1'}[key] || ''); });
function send(event, payload) {socket.send(JSON.stringify({event,context,...(payload ? {payload} : {})}));}
fields.forEach(key => $(key).addEventListener('input', () => {dirty=true;pending=null;clearTimeout(timer);$('feedback').textContent=strings.unsaved;}));
$('save').addEventListener('click', () => {
  if (!socket || socket.readyState !== WebSocket.OPEN) {$('feedback').textContent=strings.disconnected;return;}
  try {
    pending = {...settings,...snapshotSettings(Object.fromEntries(fields.map(key => [key,$(key).value])))};
    dirty=true;clearTimeout(timer);send('setSettings',pending);send('getSettings');$('feedback').textContent=strings.saving;
    timer=setTimeout(()=>{pending=null;$('feedback').textContent=strings.save_failed;},4000);
  } catch(error) {pending=null;$('feedback').textContent=strings['invalid_'+error.message] || strings.save_failed;}
});
window.connectElgatoStreamDeckSocket = async (port,uuid,registerEvent,info,actionInfo) => {
  const locale = JSON.parse(info).application.language.startsWith('es') ? 'es' : 'en';
  strings=(await (await fetch('snapshot-locales.json')).json())[locale];
  document.documentElement.lang=locale;
  fields.forEach(key => {$(key+'Label').textContent=strings[key];});
  $('save').textContent=strings.save;$('hint').textContent=strings.hint;
  const instance=JSON.parse(actionInfo);context=uuid;actionContext=instance.context;settings=instance.payload?.settings || {};render();
  socket=new WebSocket(`ws://127.0.0.1:${port}`);
  socket.onopen=()=>{socket.send(JSON.stringify({event:registerEvent,uuid}));send('getSettings');};
  socket.onclose=socket.onerror=()=>{clearTimeout(timer);pending=null;$('feedback').textContent=strings.disconnected;};
  socket.onmessage=event=>{
    const data=JSON.parse(event.data);
    if(data.event!=='didReceiveSettings'||![context,actionContext].includes(data.context))return;
    const received=data.payload.settings || {};
    if(pending && fields.every(key=>received[key]===pending[key])){clearTimeout(timer);pending=null;dirty=false;settings=received;render();$('feedback').textContent=strings.saved;}
    else if(!dirty){settings=received;render();}
  };
};
