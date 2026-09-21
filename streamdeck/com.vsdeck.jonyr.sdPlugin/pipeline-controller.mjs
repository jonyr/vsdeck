import {awsImage} from './aws-appearance.mjs';
import {pipelineSettings, pipelineKey} from './pipeline-settings.mjs';

// Poll independently per destination. Status polling only reads local Hammerspoon state; AWS is queried on a key press.
export class PipelineController {
  constructor({call, send, schedule = setTimeout, cancel = clearTimeout}) {
    Object.assign(this, {call, send, schedule, cancel});
    this.contexts = new Map(); this.jobs = new Map(); this.images = new Map();
  }
  appear(context, raw) {
    try {
      const settings = pipelineSettings(raw), key = pipelineKey(settings);
      this.contexts.set(context, {key, settings});
      if (!this.jobs.has(key)) this.jobs.set(key, {settings, state:'idle'});
      this.render(); void this.refresh(key);
    } catch { this.contexts.delete(context); this.image(context, 'error'); }
  }
  disappear(context) { this.contexts.delete(context); this.images.delete(context); }
  image(context, state, color, foreground) {
    const image = awsImage('pipeline',state,color,foreground);
    if (this.images.get(context) === image) return;
    this.images.set(context, image);
    this.send('setImage', context, {image, target:0});
  }
  render() {
    for (const [context, {key, settings}] of this.contexts) {
      const state = this.jobs.get(key).state;
      this.image(context, ({done:'idle',busy:'busy',error:'error',unknown:'error'})[state] || 'idle', settings.backgroundColor, settings.iconColor);
    }
  }
  queue(key) {
    const job = this.jobs.get(key); this.cancel(job.timer);
    if (job.state === 'busy' || job.state === 'unknown' || [...this.contexts.values()].some(v => v.key === key)) {
      job.timer = this.schedule(() => void this.refresh(key), job.state === 'busy' ? 2000 : 5000);
    }
  }
  async refresh(key) {
    const job = this.jobs.get(key);
    if (job.reading || job.starting) return;
    job.reading = true;
    const revision = job.revision;
    try {
      const status = await this.call('status', null, job.settings);
      if (!['idle','busy','done','error','cancelled'].includes(status.state)) throw new Error('status');
      if (revision === job.revision) job.state = status.state;
    } catch { if (revision === job.revision && job.state !== 'busy') job.state = 'unknown'; }
    finally { job.reading = false; this.render(); this.queue(key); }
  }
  async press(id, context, raw) {
    let settings;
    try { settings = pipelineSettings(raw); } catch { this.image(context,'error'); this.send('showAlert',context); return; }
    const key = pipelineKey(settings);
    this.contexts.set(context,{key,settings});
    if (!this.jobs.has(key)) this.jobs.set(key,{settings,state:'idle'});
    const job = this.jobs.get(key);
    if (job.starting || job.state === 'busy') return;
    // A disconnected bridge must be read successfully before accepting another press.
    if (job.state === 'unknown') { void this.refresh(key); this.send('showAlert',context); return; }
    job.settings = settings; job.starting = true; job.revision = (job.revision || 0) + 1;
    job.state = 'busy'; this.cancel(job.timer); this.render();
    try { const status = await this.call('start',id,settings); if (!['busy','done','error','cancelled'].includes(status.state)) throw new Error('status'); job.state = status.state; }
    catch { job.state = 'unknown'; this.send('showAlert',context); }
    finally {job.starting = false;this.render();this.queue(key);}
  }
}
