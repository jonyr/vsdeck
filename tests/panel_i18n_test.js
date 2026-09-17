// Run the actual panel script with a minimal DOM; no browser or external services.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { execFileSync } = require('node:child_process');
const html = fs.readFileSync('modules/deck/panel.html', 'utf8');
function element() {
  return { dataset: {}, attrs: {}, children: [], listeners: {}, value: '',
    setAttribute(k, v) { this.attrs[k] = v; }, getAttribute(k) { return this.attrs[k]; },
    addEventListener(k, fn) { this.listeners[k] = fn; },
    append(...children) { this.children.push(...children); }, replaceChildren() { this.children = []; },
    focus() {}, style: {}, className: '', textContent: '' };
}
for (const language of ['es', 'en']) {
  const source = execFileSync(process.env.LUA || 'lua', ['-'], {encoding:'utf8', input: `
local catalog = require('modules.i18n.locales.${language}')
local function encode(value)
  if type(value) == 'string' then
    return '"' .. value:gsub('\\\\', '\\\\\\\\'):gsub('"', '\\\\"'):gsub('\\n', '\\\\n') .. '"'
  end
  local result = {}
  for key, entry in pairs(value) do result[#result+1] = encode(key) .. ':' .. encode(entry) end
  return '{' .. table.concat(result, ',') .. '}'
end
print(encode(catalog))
`});
  const messages = JSON.parse(source);
  const ids = {};
  for (const id of ['search','grid','empty','count','close','mode']) ids[id] = element();
  ids.mode.value = 'replace';
  const translated = [...html.matchAll(/data-i18n="([^"]+)"/g)].map(match => {
    const el = element(); el.dataset.i18n = match[1]; return el;
  });
  const attributes = {};
  for (const suffix of ['aria','title','placeholder']) {
    attributes[suffix] = [...html.matchAll(new RegExp(`data-i18n-${suffix}="([^"]+)"`, 'g'))].map(match => {
      const el = element(); el.attrs[`data-i18n-${suffix}`] = match[1]; return el;
    });
  }
  const tabs = ['Todas','Texto','Ventanas','Web','Tareas','Luces','Sonidos'].map(category => {
    const el = element(); el.dataset.category = category; return el;
  });
  const document = { documentElement: {}, getElementById: id => ids[id], createElement: element,
    addEventListener() {}, querySelectorAll(selector) {
      if (selector === '[data-i18n]') return translated;
      if (selector === 'nav button') return tabs;
      return attributes[selector.match(/data-i18n-(\w+)/)[1]];
    }};
  const script = html.match(/<script>([\s\S]*?)<\/script>/)[1]
    .replace('__DECK_ACTIONS__', () => JSON.stringify([{id:'test',title:'Safe <b>title</b>',subtitle:'Test',keywords:'test',badge:'T',category:'Texto'},{id:'soundboard.clip.test',title:'Sound',subtitle:'Play',keywords:'audio',badge:'♪',category:'Sonidos'},{id:'soundboard.stop',title:'Stop',subtitle:'Stop',keywords:'audio',badge:'■',category:'Sonidos'}]))
    .replace('__DECK_LOCALE__', () => JSON.stringify({language,messages}));
  const sent = [];
  vm.runInNewContext(script, {document, window:{webkit:{messageHandlers:{deck:{postMessage: body => sent.push(body)}}}, matchMedia:()=>({matches:false}), addEventListener(){}}, setTimeout(){}});
  assert.equal(document.documentElement.lang, language);
  for (const el of translated) assert.equal(el.textContent, messages[el.dataset.i18n]);
  for (const [suffix, attribute] of [['aria','aria-label'],['title','title'],['placeholder','placeholder']]) {
    for (const el of attributes[suffix]) assert.equal(el.attrs[attribute], messages[el.attrs[`data-i18n-${suffix}`]]);
  }
  assert.equal(ids.count.textContent, messages['deck.count'].other.replace('{count}', '3'));
  assert.equal(ids.grid.children[0].children[1].textContent, 'Safe <b>title</b>');
  tabs[2].listeners.click();
  assert.equal(ids.count.textContent, messages['deck.count'].other.replace('{count}', '0'));
  assert.equal(ids.empty.hidden, false);
  tabs[6].listeners.click();
  assert.equal(ids.grid.children.length, 2);
  ids.grid.children[0].listeners.click();
  ids.grid.children[0].listeners.click();
  ids.grid.children[1].listeners.click();
  assert.deepEqual(sent.map(body => body.id), ['soundboard.clip.test','soundboard.clip.test','soundboard.stop']);
}
console.log('PASS: actual panel script in Spanish/English, labels, accessibility, plural counts, stable category filtering and plain text rendering.');
