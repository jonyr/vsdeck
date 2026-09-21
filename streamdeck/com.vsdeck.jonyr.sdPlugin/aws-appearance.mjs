import {readFileSync} from 'node:fs';

import {backgroundColor, defaultBackgroundColor, iconColor} from './aws-appearance-settings.mjs';
export {backgroundColor, defaultBackgroundColor, iconColor};
const templates = new Map();
// Customize only the resting state; execution feedback keeps its established colors.
export function awsImage(action, state, color = defaultBackgroundColor, foreground = '') {
  if (!['pipeline','snapshot','translate','correct','structure','email'].includes(action)) throw new Error('Invalid image action');
  if (!['idle','busy','done','error'].includes(state)) throw new Error('Invalid image state');
  const path = `images/${['translate','correct','structure','email'].includes(action) ? '' : 'aws-'}${action}-${state}.svg`;
  if (state !== 'idle') return path;
  color = backgroundColor(color);
  foreground = iconColor(foreground);
  if (color === defaultBackgroundColor && foreground === '#FFFFFF') return path;
  if (!templates.has(action)) templates.set(action, readFileSync(new URL(`./${path}`, import.meta.url),'utf8'));
  const svg = templates.get(action).replace(/fill="#2563eb"/i,`fill="${color}"`).replace('stroke="white"',`stroke="${foreground}"`);
  return `data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`;
}
