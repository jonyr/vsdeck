import {presenceImage} from './presence-appearance.mjs';
// Presence is observed from Discord; a key press never predicts a successful toggle.
export class PresenceController {
  constructor({call, send, schedule = setTimeout, cancel = clearTimeout}) {
    Object.assign(this, {call, send, schedule, cancel});
    this.contexts = new Set();
    this.settings = new Map();
    this.rendered = new Map();
    this.actions = new Map();
    this.state = 'unknown';
    this.inFlight = false;
    this.revision = 0;
    this.errorId = null;
  }
  render() {
    for (const context of this.contexts) {
      const mode = this.actions.get(context);
      const settings = this.settings.get(context) || {};
      const feedback = context === this.owner && ['busy','error'].includes(this.state);
      const target = mode === 'presence' && ['online','away','dnd','invisible'].includes(settings.target) ? settings.target : 'away';
      const image = presenceImage(mode, feedback ? this.state : target, settings, feedback);
      if (this.rendered.get(context) === image) continue;
      this.send('setImage', context, {image, target: 0});
      this.rendered.set(context, image);
    }
  }
  accept(status) {
    if (!status || !['idle','busy','done','error'].includes(status.state)) throw new Error('Invalid presence response');
    if (status.id !== this.ownerId) this.owner = null;
    const error = status.state === 'error' && this.errorId !== status.id;
    if (error) this.errorId = status.id;
    this.state = error ? 'error' : status.state === 'busy' ? 'busy' :
      ['online','away','dnd','invisible'].includes(status.presence) ? status.presence : 'unknown';
    this.render();
    this.queue(status.state === 'busy' ? 500 : error ? 2000 : 5000);
  }
  queue(delay) {
    this.cancel(this.timer);
    if (this.contexts.size || this.state === 'busy') this.timer = this.schedule(() => this.refresh(), delay);
  }
  async refresh() {
    if (this.inFlight) return;
    this.inFlight = true;
    const revision = this.revision;
    try {
      this.readTask = this.call('status');
      const result = await this.readTask;
      if (revision === this.revision) this.accept(result);
    } catch {
      this.state = 'unknown'; this.render(); this.queue(5000);
    } finally { this.inFlight = false; this.readTask = null; }
  }
  appear(context, settings = {}, mode = 'lunch') { this.actions.set(context, mode); this.settings.set(context, settings); this.contexts.add(context); this.render(); void this.refresh(); }
  updateSettings(context, settings) { this.settings.set(context, settings || {}); this.render(); }
  disappear(context) {
    this.settings.delete(context);
    this.rendered.delete(context);
    this.actions.delete(context);
    this.contexts.delete(context);
    if (!this.contexts.size && this.state !== 'busy') this.cancel(this.timer);
  }
  async press(id, context, options = {}) {
    // Multi-action children need not have willAppear; use this keyDown's settings
    // and action type, never a last-visible action or a default lunch toggle.
    const settings = {...(options.settings ?? this.settings.get(context)), mode:options.mode || this.actions.get(context) || 'lunch'};
    if (this.state === 'busy') return;
    if (this.readTask) { try { await this.readTask; } catch {} }
    if (this.inFlight || this.state === 'busy') return;
    this.cancel(this.timer);
    this.revision++;
    this.inFlight = true;
    this.owner = context; this.ownerId = id;
    this.state = 'busy'; this.render();
    try { this.accept(await this.call('start', id, settings)); }
    catch { this.state = 'error'; this.render(); this.queue(2000); }
    finally { this.inFlight = false; }
  }
}
