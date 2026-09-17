// Verifies the single-file build and copies it next to the original panel.
import { copyFileSync, readFileSync } from 'node:fs';

const source = new URL('../dist/index.html', import.meta.url);
const target = new URL('../../modules/deck/panel.react.html', import.meta.url);
const html = readFileSync(source, 'utf8');

const fail = message => { console.error(`check-build: ${message}`); process.exit(1); };
// init.lua substitutes every occurrence, so the placeholder must appear exactly once.
const placeholders = html.split('__DECK_ACTIONS__').length - 1;
if (placeholders !== 1) fail(`expected 1 __DECK_ACTIONS__ placeholder, found ${placeholders}`);
if (/<script[^>]+src=|<link[^>]+href=/.test(html)) fail('external script or stylesheet reference left in build');
if (!html.includes('Content-Security-Policy')) fail('Content-Security-Policy meta tag missing');

copyFileSync(source, target);
console.log(`check-build: ok (${(html.length / 1024).toFixed(0)} KB) → modules/deck/panel.react.html`);
