import {presenceSettings, defaults} from './presence-settings.mjs';
const $ = id => document.getElementById(id);
const fields = ['emoji','message','duration','target','presenceDuration','backgroundColor','iconColor'];
let socket, context, actionContext, action, settings = {}, strings, mode = 'lunch', pending, saveTimer;
let dirty = false;
const presenceDurations = ['15m','1h','8h','24h','3d','forever'];
function updateDuration() {
  const button = $('presenceDuration');
  button.disabled = mode === 'presence' && $('target').value === 'online';
  button.textContent = strings?.[button.value] || '';
  if (button.disabled) {
    $('presenceDurationOptions').hidden = true;
    button.setAttribute?.('aria-expanded', 'false');
  }
  for (const option of $('presenceDurationOptions').children) option.setAttribute?.('aria-pressed', String(option.value === button.value));
}
$('presenceDuration').addEventListener('click', () => {
  if ($('presenceDuration').disabled) return;
  const list = $('presenceDurationOptions');
  list.hidden = !list.hidden;
  $('presenceDuration').setAttribute?.('aria-expanded', String(!list.hidden));
});

function render() {
  const current = {...defaults, ...settings};
  for (const key of fields) $(key).value = current[key];
  $('backgroundColor').placeholder = ({online:'#16A34A',away:'#EA780C',dnd:'#B91C1C',invisible:'#64748B'})[$('target').value] || '#EA780C';
  updateDuration();
}
function send(event, payload) { socket.send(JSON.stringify({event,context,action,...(payload ? {payload} : {})})); }
function save() {
  if (!socket || socket.readyState !== WebSocket.OPEN) { $('feedback').textContent = strings.disconnected; return; }
  try {
    const values = presenceSettings({...Object.fromEntries(fields.map(key=>[key,$(key).value])), mode});
    pending = {...settings, ...values};
    send('setSettings', pending);
    send('getSettings');
    $('feedback').textContent = strings.saving;
    clearTimeout(saveTimer);
    saveTimer = setTimeout(()=>{pending = null; $('feedback').textContent = strings.save_failed;},4000);
  } catch (error) { $('feedback').textContent = strings['invalid_' + error.message] || strings.invalid_message; }
}
for (const key of fields) $(key).addEventListener('input', () => {
  dirty = true; pending = null; clearTimeout(saveTimer);
  $('feedback').textContent = strings.unsaved;
  $('backgroundColor').placeholder = ({online:'#16A34A',away:'#EA780C',dnd:'#B91C1C',invisible:'#64748B'})[$('target').value] || '#EA780C';
  updateDuration();
});
$('save').addEventListener('click',save);
window.connectElgatoStreamDeckSocket = async (port, uuid, registerEvent, info, actionInfo) => {
  const registration = JSON.parse(info);
  const catalogs = await (await fetch('presence-locales.json')).json();
  const locale = registration.application.language.startsWith('es') ? 'es' : 'en';
  strings = catalogs[locale];
  document.documentElement.lang = locale;
  for (const key of fields) $(key + 'Label').textContent = strings[key];
  $('save').textContent = strings.save;
  $('emojiHelp').textContent = strings.emoji_help;
  $('appearanceHelp').textContent = strings.appearance_help;
  const instance = JSON.parse(actionInfo);
  // Stream Deck routes inspector settings commands through its registration UUID.
  context = uuid; actionContext = instance.context; action = instance.action;
  mode = action.endsWith('discord-presence') ? 'presence' : 'lunch';
  for (const key of ['emoji','message','duration']) { $(key).hidden = mode === 'presence'; $(key+'Label').hidden = mode === 'presence'; }
  $('emojiHelp').hidden = mode === 'presence';
  $('target').hidden = mode === 'lunch'; $('targetLabel').hidden = mode === 'lunch';
  $('hint').textContent = strings[mode === 'presence' ? 'presence_hint' : 'hint'];
  for (const [field,values] of [['duration',['30m','1h','4h','24h','never']],['target',['online','away','dnd','invisible']]]) {
    for (const value of values) { const option=document.createElement('option'); option.value=value;option.textContent=strings[value];$(field).append(option); }
  }
  for (const value of presenceDurations) {
    const option = document.createElement('button');
    option.type = 'button'; option.value = value; option.textContent = strings[value];
    option.addEventListener('click', () => {
      $('presenceDuration').value = value;
      dirty = true; pending = null; clearTimeout(saveTimer);
      $('feedback').textContent = strings.unsaved;
      $('presenceDurationOptions').hidden = true;
      $('presenceDuration').setAttribute?.('aria-expanded', 'false');
      updateDuration();
    });
    $('presenceDurationOptions').append(option);
  }
  settings = instance.payload?.settings || {};
  render();
  socket = new WebSocket(`ws://127.0.0.1:${port}`);
  socket.onopen = () => {socket.send(JSON.stringify({event:registerEvent,uuid}));send('getSettings');};
  socket.onclose = socket.onerror = () => {clearTimeout(saveTimer);pending=null;$('feedback').textContent=strings.disconnected;};
  socket.onmessage = event => {
    const data=JSON.parse(event.data);
    if (data.event !== 'didReceiveSettings' || ![context,actionContext].includes(data.context)) return;
    const received = data.payload.settings || {};
    if (pending && Object.keys(pending).every(key=>received[key] === pending[key])) {
      clearTimeout(saveTimer);pending=null;dirty=false;settings=received;render();$('feedback').textContent=strings.saved;
    } else if (!dirty) {settings=received;render();}
  };
};
