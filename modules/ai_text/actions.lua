--- Define text transformations and their localized Stream Deck metadata.
-- @module modules.ai_text.actions

local t = require('modules.i18n').t
local structurePrompt =
  'Organize the supplied unstructured text into a clear, readable document in its original language and tone. Start with a concise descriptive title derived only from the source, followed by a blank line. Group related ideas into short paragraphs separated by blank lines. Use bullet points for genuine lists of parallel items, and numbered steps only when the source specifies an order. Do not force every sentence into a list. Preserve all substantive details, dates, names, amounts, links, negations, uncertainty, and commitments; do not summarize away information or invent facts, conclusions, tasks, or headings unsupported by the source. Correct obvious spelling and grammar as needed. Preserve any existing code and identifiers exactly. '
-- Keep prompts independent of translated display labels; IDs are public dispatch keys.
local actions = {
  {
    id = 'translate_en',
    title = t('actions.translate_en.title'),
    badge = 'EN',
    keywords = 'ingles english translate traducir',
    subtitle = t('actions.translate_en.subtitle'),
    prompt = 'Correct errors and translate the text into natural English. Preserve the intended tone and level of formality.',
  },
  {
    id = 'fix_same_language',
    title = t('actions.fix_same_language.title'),
    badge = 'FIX',
    keywords = 'corregir fix grammar gramatica spelling claridad',
    subtitle = t('actions.fix_same_language.subtitle'),
    prompt = 'Correct grammar, spelling, clarity, and flow with only necessary edits. Preserve the original language, voice, and tone. Leave text that already reads well unchanged.',
  },
  {
    id = 'structure',
    title = t('actions.structure.title'),
    badge = 'LIST',
    keywords = 'estructura structure organizar organizar formato paragraphs bullets',
    subtitle = t('actions.structure.subtitle'),
    prompt = structurePrompt
      .. 'Return only the organized document as plain text, with a standalone title and • bullets, without a preamble, code fence, HTML, or Markdown heading/bold markers.',
    markdownPrompt = structurePrompt
      .. 'Return only the organized document in Markdown. Use # for the main title, ## for useful section headings, - for bullet lists, and blank lines between paragraphs. Do not wrap the entire result in a code fence, add a preamble, or use HTML.',
  },
  {
    id = 'email',
    title = t('actions.email.title'),
    badge = 'MAIL',
    keywords = 'email mail correo subject asunto',
    subtitle = t('actions.email.subtitle'),
    prompt = 'Rewrite the text as a concise, professional email in the original language. Start with a short subject line labeled in that language, then a blank line and the body. Use only information supplied in the text. Do not invent recipient or sender names, signatures, commitments, or missing context, and do not add placeholders.',
  },
}

-- Build a lookup alongside the ordered list so interfaces can dispatch by stable ID.
local byId = {}

for _, action in ipairs(actions) do
  byId[action.id] = action
end

return {
  list = actions,
  byId = byId,
}
