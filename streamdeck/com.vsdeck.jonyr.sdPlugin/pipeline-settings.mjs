import {backgroundColor, iconColor} from './aws-appearance-settings.mjs';
export const fields = ['iconColor', 'backgroundColor', 'title', 'profile', 'region', 'pipeline'];
export function pipelineSettings(input = {}) {
  const value = Object.fromEntries(fields.map(key => [key, typeof input[key] === 'string' ? input[key].trim() : '']));
  value.region ||= 'us-east-1';
  value.iconColor = iconColor(value.iconColor);
  value.backgroundColor = backgroundColor(value.backgroundColor);
  if ([...value.title].length > 160 || /[\u0000-\u001f\u007f]/.test(value.title)) throw new Error('title');
  if (!/^[a-zA-Z0-9_-]{1,128}$/.test(value.profile)) throw new Error('profile');
  if (value.region && !/^[a-z0-9-]{1,64}$/.test(value.region)) throw new Error('region');
  if (!/^[a-zA-Z0-9.@_-]{1,100}$/.test(value.pipeline)) throw new Error('pipeline');
  if (!value.title) value.title = value.pipeline;
  return value;
}
export const pipelineKey = settings => JSON.stringify(['profile', 'region', 'pipeline'].map(key => settings[key]));
