local t = require('modules.i18n').t
local actions = {
  {
    id = 'translate_en',
    title = t('actions.translate_en.title'),
    badge = 'EN',
    keywords = 'ingles english translate traducir',
    subtitle = t('actions.translate_en.subtitle'),
    prompt = 'Correct errors and translate the text into natural English. Preserve the intended tone and level of formality.'
  },
  {
    id = 'fix_same_language',
    title = t('actions.fix_same_language.title'),
    badge = 'FIX',
    keywords = 'corregir fix grammar gramatica spelling claridad',
    subtitle = t('actions.fix_same_language.subtitle'),
    prompt = 'Correct grammar, spelling, clarity, and flow with only necessary edits. Preserve the original language, voice, and tone. Leave text that already reads well unchanged.'
  },
  {
    id = 'translate_es',
    title = t('actions.translate_es.title'),
    badge = 'ES',
    keywords = 'espanol spanish translate traducir',
    subtitle = t('actions.translate_es.subtitle'),
    prompt = 'Translate the text into natural, clear Spanish. Preserve the intended tone and level of formality. Use broadly understood Spanish without introducing regional slang.'
  },
  {
    id = 'professional',
    title = t('actions.professional.title'),
    badge = 'PRO',
    keywords = 'profesional professional tone tono polish',
    subtitle = t('actions.professional.subtitle'),
    prompt = 'Rewrite the text in a natural, professional, concise tone without inflated or overly formal wording. Keep the original language.'
  },
  {
    id = 'shorten',
    title = t('actions.shorten.title'),
    badge = 'SUM',
    keywords = 'resumir shorten shorter summary corto claro',
    subtitle = t('actions.shorten.subtitle'),
    prompt = 'Summarize the text concisely in the original language. Retain the main points, decisions, required actions, and material conditions, including relevant dates, amounts, negations, and uncertainty. Remove repetition and secondary detail without changing the conclusions.'
  },
  {
    id = 'email',
    title = t('actions.email.title'),
    badge = 'MAIL',
    keywords = 'email mail correo subject asunto',
    subtitle = t('actions.email.subtitle'),
    prompt = 'Rewrite the text as a concise, professional email in the original language. Start with a short subject line labeled in that language, then a blank line and the body. Use only information supplied in the text. Do not invent recipient or sender names, signatures, commitments, or missing context, and do not add placeholders.'
  },
  {
    id = 'chat',
    title = t('actions.chat.title'),
    badge = 'CHAT',
    keywords = 'chat slack teams discord mensaje breve',
    subtitle = t('actions.chat.subtitle'),
    prompt = 'Rewrite the text as a concise, direct chat message in the original language. Keep a natural, approachable tone without adding familiarity, enthusiasm, emojis, greetings, or sign-offs that are absent from the original.'
  },
  {
    id = 'auto',
    title = t('actions.auto.title'),
    badge = 'AUTO',
    keywords = 'auto automatic automatico detectar ingles espanol',
    subtitle = t('actions.auto.subtitle'),
    prompt = 'If the prose is Spanish, correct errors and translate it into natural English. If it is English, correct it with only necessary edits. If the prose mixes Spanish and English, normalize it to natural English. For other languages or language combinations, correct errors without translating. Preserve the intended tone and formality. Do not treat code, identifiers, or isolated technical terms as evidence of mixed-language prose.'
  }
}

local byId = {}

for _, action in ipairs(actions) do
  byId[action.id] = action
end

return {
  list = actions,
  byId = byId
}
