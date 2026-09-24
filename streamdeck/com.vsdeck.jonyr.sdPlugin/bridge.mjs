import {scriptSettings} from './script-settings.mjs';
import {textSettings} from './text-settings.mjs';
import {pipelineSettings} from './pipeline-settings.mjs';
import { presenceSettings, luaJson } from './presence-settings.mjs';
import { execFile } from 'node:child_process';
import { snapshotSettings } from './snapshot-settings.mjs';

// hs detects piped stdin and waits for EOF, even when a -c command is provided.
// Close it explicitly so the command returns instead of hitting our timeout.
export function runJsonCommand(executable, args, timeout = 5000) {
  return new Promise((resolve, reject) => {
    const child = execFile(executable, args, { timeout, maxBuffer: 16384 }, (error, stdout) => {
      if (error) { reject(error); return; }
      try { resolve(JSON.parse(stdout.trim())); }
      catch { reject(new Error('Invalid bridge response')); }
    });
    child.stdin.on('error', () => {}); // A child that exits early can close its input first.
    child.stdin.end();
  });
}

export async function call(method, id, action = 'translate', settings = {}) {
  if (!['start', 'status'].includes(method) || (method === 'start' && !/^[a-z0-9-]{1,64}$/i.test(id))) throw new Error('Invalid bridge request');
  if (!['translate', 'correct', 'structure', 'email'].includes(action)) throw new Error('Invalid action');
  const expression = method === 'start' ? `start('${id}', '${action}', hs.json.decode(${luaJson(textSettings(settings))}))` : 'status()';
  return runJsonCommand('/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs', [
    '-q', '-c', `return hs.json.encode(require('modules.streamdeck').${expression})`,
  ]);
}

export async function callPresence(method, id, settings) {
  if (!['start', 'status'].includes(method) || (method === 'start' && !/^[a-z0-9-]{1,64}$/i.test(id))) throw new Error('Invalid presence request');
  const expression = method === 'start' ? `start('${id}', hs.json.decode(${luaJson(presenceSettings(settings))}))` : 'status()';
  return runJsonCommand('/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs', [
    '-q', '-c', `return hs.json.encode(require('modules.discord.presence').${expression})`,
  ]);
}

export async function callSnapshot(method, id, settings) {
  if (!['start', 'status'].includes(method) || (method === 'start' && !/^[a-z0-9-]{1,64}$/i.test(id))) throw new Error('Invalid snapshot request');
  const target = `hs.json.decode(${luaJson(snapshotSettings(settings))})`;
  const expression = method === 'start' ? `start('${id}', ${target})` : `status(${target})`;
  return runJsonCommand('/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs', ['-q', '-c', `return hs.json.encode(require('modules.tasks.snapshots').${expression})`]);
}

export async function callPipeline(method, id, settings) {
  if (!['start', 'status'].includes(method) || (method === 'start' && !/^[a-z0-9-]{1,64}$/i.test(id))) throw new Error('Invalid pipeline request');
  const target = `hs.json.decode(${luaJson(pipelineSettings(settings))})`;
  const expression = method === 'start' ? `start('${id}', ${target})` : `status(${target})`;
  return runJsonCommand('/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs', ['-q', '-c', `return hs.json.encode(require('modules.tasks.pipelines').${expression})`]);
}

export async function callScript(method, id, settings) {
  if (!['start', 'status'].includes(method) || (method === 'start' && !/^[a-z0-9-]{1,64}$/i.test(id))) throw new Error('Invalid script request');
  const target = `hs.json.decode(${luaJson(scriptSettings(settings))})`;
  const expression = method === 'start' ? `start('${id}', ${target})` : `status(${target})`;
  return runJsonCommand('/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs', ['-q', '-c', `return hs.json.encode(require('modules.tasks.scripts').${expression})`]);
}
