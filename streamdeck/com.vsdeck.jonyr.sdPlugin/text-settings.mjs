import {backgroundColor, iconColor} from './aws-appearance-settings.mjs';
export const languages = {en:'English',es:'Español',pt:'Português',fr:'Français',de:'Deutsch',it:'Italiano',ja:'日本語',zh:'中文',ko:'한국어',nl:'Nederlands',ru:'Русский',ar:'العربية'};
export const fields = ['provider','targetLanguage','outputFormat','backgroundColor','iconColor'];
export function textSettings(value = {}) {
 const provider = value.provider || 'lmstudio';
 if (!['lmstudio','openrouter'].includes(provider)) throw new Error('provider');
 const outputFormat = value.outputFormat || 'plain';
 if (!['plain','markdown'].includes(outputFormat)) throw new Error('outputFormat');
 const targetLanguage = value.targetLanguage || 'en';
 if (!Object.hasOwn(languages,targetLanguage)) throw new Error('targetLanguage');
 return {provider,targetLanguage,outputFormat,backgroundColor:backgroundColor(value.backgroundColor),iconColor:iconColor(value.iconColor)};
}
