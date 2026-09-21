import { PipelineController } from './pipeline-controller.mjs';
import WebSocket from 'ws';
import { randomUUID } from 'node:crypto';
import { Controller } from './controller.mjs';
import { handlePresenceEvent } from './presence-events.mjs';
import { PresenceController } from './presence-controller.mjs';
import { call, callPresence, callSnapshot, callPipeline } from './bridge.mjs';
import { SnapshotController } from './snapshot-controller.mjs';

const args = Object.fromEntries(Array.from({ length: (process.argv.length - 2) / 2 }, (_, i) => process.argv.slice(2 + i * 2, 4 + i * 2)));
const port = Number(args['-port']);
if (!Number.isInteger(port) || port < 1 || port > 65535 || !args['-pluginUUID'] || args['-registerEvent'] !== 'registerPlugin') {
  throw new Error('Invalid Stream Deck launch arguments');
}
const socket = new WebSocket(`ws://127.0.0.1:${port}`);
const controller = new Controller({ call, send(event, context, payload) {
  if (socket.readyState === WebSocket.OPEN) socket.send(JSON.stringify({ event, context, ...(payload ? { payload } : {}) }));
} });
const presence = new PresenceController({call: callPresence, send: controller.send});
const pipelines = new PipelineController({call:callPipeline,send:controller.send});
const snapshots = new SnapshotController({call:callSnapshot,send:controller.send});
socket.on('open', () => socket.send(JSON.stringify({ event: args['-registerEvent'], uuid: args['-pluginUUID'] })));
socket.on('message', raw => {
  let message;
  try { message = JSON.parse(raw.toString()); } catch { return; }
  if (message.action === 'com.vsdeck.jonyr.aws-pipeline') {
    if (['willAppear','didReceiveSettings'].includes(message.event)) pipelines.appear(message.context,message.payload?.settings);
    if (message.event === 'willDisappear') pipelines.disappear(message.context);
    if (message.event === 'keyDown') void pipelines.press(randomUUID(),message.context,message.payload?.settings);
    return;
  }
  if (message.action === 'com.vsdeck.jonyr.aws-snapshot') {
    if (['willAppear','didReceiveSettings'].includes(message.event)) snapshots.appear(message.context,message.payload?.settings);
    if (message.event === 'willDisappear') snapshots.disappear(message.context);
    if (message.event === 'keyDown') void snapshots.press(randomUUID(),message.context,message.payload?.settings);
    return;
  }
  if (handlePresenceEvent(presence, message, randomUUID)) return;
  const action = { 'com.vsdeck.jonyr.english': 'translate', 'com.vsdeck.jonyr.correct': 'correct', 'com.vsdeck.jonyr.structure': 'structure', 'com.vsdeck.jonyr.email': 'email' }[message.action];
  if (!action) return;
  if (message.event === 'willAppear') void controller.appear(message.context, action, message.payload?.settings);
  if (message.event === 'willDisappear') controller.disappear(message.context);
  if (message.event === 'didReceiveSettings') controller.configure(message.context, message.payload?.settings);
  if (message.event === 'keyDown') void controller.press(randomUUID(), action, message.payload?.settings, message.context);
});
socket.on('error', () => process.exit(1));
socket.on('close', () => process.exit(0));
