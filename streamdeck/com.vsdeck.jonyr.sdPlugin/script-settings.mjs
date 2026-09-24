import {backgroundColor, iconColor} from './aws-appearance-settings.mjs';
export const fields = ['title','script','cwd','mode','args','selection','backgroundColor','iconColor'];
export function scriptSettings(input = {}) {
  const value = Object.fromEntries(fields.map(key => [key,typeof input[key] === 'string' ? input[key].trim() : '']));
  value.mode ||= 'options'; value.args ||= '[]'; value.selection ||= '{}';
  if (!value.script || value.script.length > 4096 || /[\x00-\x1f\x7f]/.test(value.script)) throw new Error('script');
  if (value.cwd && (!value.cwd.startsWith('/') || /[\x00-\x1f\x7f]/.test(value.cwd))) throw new Error('cwd');
  if (value.title.length > 160 || /[\x00-\x1f\x7f]/.test(value.title)) throw new Error('title');
  if (!['options','direct'].includes(value.mode)) throw new Error('mode');
  try {
    const args = JSON.parse(value.args), selection = JSON.parse(value.selection);
    if (value.args.length>8192 || !Array.isArray(args) || args.length>64 || args.some(v=>typeof v!=='string'||v.length>4096||v.includes('\0'))) throw 0;
    if (value.selection.length>8192 || !selection || Array.isArray(selection) || typeof selection!=='object' || Object.entries(selection).some(([k,v])=>!/^[a-z][a-z0-9_-]*$/i.test(k)||typeof v!=='string'||v.length>1024||v.includes('\0'))) throw 0;
    value.args=JSON.stringify(args); value.selection=JSON.stringify(selection);
  } catch { throw new Error('json'); }
  value.backgroundColor=backgroundColor(value.backgroundColor); value.iconColor=iconColor(value.iconColor);
  return value;
}
export const scriptKey = settings => JSON.stringify(['script','cwd','args','mode','selection'].map(key=>settings[key]));
