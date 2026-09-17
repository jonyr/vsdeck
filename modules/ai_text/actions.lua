local actions = {
  {
    id = 'translate_en',
    title = 'Traducir a ingles',
    badge = 'EN',
    keywords = 'ingles english translate traducir',
    subtitle = 'Corrige y traduce a ingles profesional',
    prompt = 'Correct the text and translate it to natural professional English.'
  },
  {
    id = 'fix_same_language',
    title = 'Corregir mismo idioma',
    badge = 'FIX',
    keywords = 'corregir fix grammar gramatica spelling claridad',
    subtitle = 'Corrige gramatica, claridad y tono sin traducir',
    prompt = 'Correct grammar, spelling, clarity, and flow. Keep the original language.'
  },
  {
    id = 'translate_es',
    title = 'Traducir a espanol',
    badge = 'ES',
    keywords = 'espanol spanish translate traducir',
    subtitle = 'Traduce a espanol claro y natural',
    prompt = 'Translate the text to natural, clear Spanish.'
  },
  {
    id = 'professional',
    title = 'Tono profesional',
    badge = 'PRO',
    keywords = 'profesional professional tone tono polish',
    subtitle = 'Reescribe con tono profesional',
    prompt = 'Rewrite the text in a professional, polished, concise tone. Keep the original language unless translation is explicitly needed.'
  },
  {
    id = 'shorten',
    title = 'Resumir',
    badge = 'SUM',
    keywords = 'resumir shorten shorter summary corto claro',
    subtitle = 'Hace el texto mas corto y claro',
    prompt = 'Make the text shorter, clearer, and easier to scan. Keep the original language.'
  },
  {
    id = 'email',
    title = 'Convertir a email',
    badge = 'MAIL',
    keywords = 'email mail correo subject asunto',
    subtitle = 'Transforma el texto en un email listo para enviar',
    prompt = 'Rewrite the text as a professional email. Include subject only if it is useful. Keep it concise.'
  },
  {
    id = 'chat',
    title = 'Convertir a mensaje',
    badge = 'CHAT',
    keywords = 'chat slack teams discord mensaje breve',
    subtitle = 'Mensaje breve para Slack, Teams o chat',
    prompt = 'Rewrite the text as a concise, friendly, direct chat message.'
  },
  {
    id = 'auto',
    title = 'Auto',
    badge = 'AUTO',
    keywords = 'auto automatic automatico detectar ingles espanol',
    subtitle = 'Si esta en espanol, traducir a ingles; si esta en ingles, corregir',
    prompt = 'If the text is Spanish, correct it and translate it to natural professional English. If it is English, correct and polish it in English. If mixed, normalize it to professional English.'
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
