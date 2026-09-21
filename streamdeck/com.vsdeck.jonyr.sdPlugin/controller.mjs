import {textSettings} from './text-settings.mjs';
import {awsImage} from './aws-appearance.mjs';
// Clipboard execution is serialized, but feedback belongs only to the initiating key.
export class Controller {
  constructor({ call, send, schedule = setTimeout, cancel = clearTimeout }) {
    Object.assign(this, { call, send, schedule, cancel });
    this.contexts = new Map();
    this.settings = new Map();
    this.action = 'translate';
    this.owner = null;
    this.requestId = null;
    this.state = 'idle';
    this.labels = {};
    this.starting = false;
    this.polling = false;
    this.revision = 0;
  }
  render(context) {
    const action = this.contexts.get(context);
    const state = context === this.owner ? this.state : 'idle';
    this.send('setImage', context, { image: awsImage(action, state, this.settings.get(context)?.backgroundColor, this.settings.get(context)?.iconColor), target: 0 });
  }
  display(state) {
    this.state = state;
    for (const context of this.contexts.keys()) this.render(context);
  }
  accept(status) {
    if (!status || !['idle', 'busy', 'done', 'error'].includes(status.state)) throw new Error('Invalid bridge status');
    if (status.id && this.requestId && status.id !== this.requestId) {
      // The bridge may return an existing job when another client holds the lock.
      this.owner = null;
      this.requestId = null;
    }
    this.action = status.action || this.action;
    this.labels = status.labels || this.labels;
    this.cancel(this.resetTimer);
    this.display(status.state === 'done' ? 'idle' : status.state);
    if (status.state === 'busy') this.poll();
    if (status.state === 'error') this.resetTimer = this.schedule(() => this.display('idle'), 2000);
  }
  failure() {
    this.cancel(this.resetTimer);
    this.display('error');
    this.resetTimer = this.schedule(() => this.display('idle'), 2000);
  }
  async appear(context, action = 'translate', settings = {}) {
    this.configure(context, settings);
    this.contexts.set(context, action);
    this.render(context);
    // An in-flight start owns state until its response; avoid stale idle results.
    if (this.starting || this.polling) return;
    const revision = ++this.revision;
    try {
      const status = await this.call('status');
      if (revision === this.revision) this.accept(status);
    } catch { if (revision === this.revision) this.failure(); }
  }
  configure(context, settings) {
    try { this.settings.set(context, textSettings(settings)); }
    catch { this.settings.set(context, textSettings()); }
    if (this.contexts.has(context)) this.render(context);
  }
  disappear(context) { this.contexts.delete(context); this.settings.delete(context); }
  async press(id, action = 'translate', settings = {}, context) {
    if (this.starting || this.state === 'busy') return;
    this.owner = context ?? [...this.contexts].find(([, value]) => value === action)?.[0] ?? null;
    this.requestId = id;
    this.action = action;
    this.revision++;
    this.starting = true;
    this.cancel(this.resetTimer);
    this.display('busy');
    try { this.accept(await this.call('start', id, action, textSettings(settings))); }
    catch { this.failure(); }
    finally { this.starting = false; }
  }
  poll() {
    if (this.polling) return;
    this.polling = true;
    this.schedule(async () => {
      try {
        const status = await this.call('status');
        this.polling = false;
        this.accept(status);
      } catch {
        this.polling = false;
        this.failure();
      }
    }, 500);
  }
}
