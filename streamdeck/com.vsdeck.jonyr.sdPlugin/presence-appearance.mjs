import {readFileSync} from 'node:fs';
export const presenceColors = {online:'#16A34A', away:'#EA780C', dnd:'#B91C1C', invisible:'#64748B'};
const templates = new Map();
export function presenceImage(mode, state, settings = {}, feedback = false) {
  const prefix = mode === 'presence' ? 'discord-presence' : 'discord-lunch';
  const path = `images/${prefix}-${state}.svg`;
  if (feedback) return path;
  const valid = value => typeof value === 'string' && /^#[0-9a-f]{6}$/i.test(value.trim());
  const background = valid(settings.backgroundColor) ? settings.backgroundColor.trim() : presenceColors[state];
  const foreground = valid(settings.iconColor) ? settings.iconColor.trim() : '#FFFFFF';
  if (background === presenceColors[state] && foreground.toUpperCase() === '#FFFFFF') return path;
  if (!templates.has(path)) templates.set(path, readFileSync(new URL(path, import.meta.url),'utf8'));
  const svg = templates.get(path).replace(/fill="#[0-9a-f]{6}"/i,`fill="${background}"`).replace('stroke="white"',`stroke="${foreground}"`);
  return `data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`;
}
