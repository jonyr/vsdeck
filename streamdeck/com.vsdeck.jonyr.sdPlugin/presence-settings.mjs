export const defaults = Object.freeze({message: '🥬 Almorzando', emoji: 'cut_of_meat', duration: '1h', mode:'lunch', target:'away', presenceDuration:'1h'});
export const durations = ['30m', '1h', '4h', '24h', 'never'];
export function presenceSettings(input = {}) {
  const settings = {...defaults, ...input};
  if (typeof settings.message !== 'string' || [...settings.message].length > 128 || /[\u0000-\u001f\u007f]/.test(settings.message)) throw new Error('message');
  if (typeof settings.emoji !== 'string') throw new Error('emoji');
  settings.emoji = settings.emoji.trim().replace(/^:|:$/g, '');
  if (!/^[a-zA-Z0-9_+\-]{0,80}$/.test(settings.emoji)) throw new Error('emoji');
  if (!durations.includes(settings.duration)) throw new Error('duration');
  if (!['lunch','presence'].includes(settings.mode)) throw new Error('mode');
  if (!['online','away','dnd','invisible'].includes(settings.target)) throw new Error('target');
  if (!['15m','1h','8h','24h','3d','forever'].includes(settings.presenceDuration)) throw new Error('presenceDuration');
  return {mode:settings.mode, target:settings.target, presenceDuration:settings.presenceDuration, message: settings.message, emoji: settings.emoji, duration: settings.duration};
}
// Decimal byte escapes prevent quotes, backslashes and Lua syntax in user text
// from becoming executable code across the local CLI boundary.
export function luaJson(value) {
  return '"' + [...Buffer.from(JSON.stringify(value), 'utf8')].map(byte => '\\' + String(byte).padStart(3, '0')).join('') + '"';
}
