--- Verify catalog parity, literal parameters, plurals, fallback and stable action contracts.
-- @script tests.i18n_test
-- Test doubles keep these assertions independent of real apps and personal settings.

package.loaded['modules.config.personal'] = { data = { language = 'en-US' } }
local i18n = require('modules.i18n')
local es, en = require('modules.i18n.locales.es'), require('modules.i18n.locales.en')
local function parameters(text)
  local names = {}
  for name in text:gmatch('{([%w_]+)}') do
    names[#names + 1] = name
  end
  table.sort(names)
  return table.concat(names, ',')
end
local count = 0
for key, value in pairs(es) do
  assert(type(en[key]) == type(value), 'Missing or incompatible key: ' .. key)
  if type(value) == 'table' then
    for _, form in ipairs({ 'one', 'other' }) do
      assert(type(value[form]) == 'string' and type(en[key][form]) == 'string', key)
      assert(parameters(value[form]) == parameters(en[key][form]), key)
    end
  else
    assert(parameters(value) == parameters(en[key]), key)
  end
  count = count + 1
end
for key in pairs(en) do
  assert(es[key] ~= nil, 'Extra English key: ' .. key)
end
assert(i18n.language() == 'en')
-- Synthetic plural fixtures exercise the translator without retired deck UI keys.
en['test.count'] = { one = '{count} action available', other = '{count} actions available' }
es['test.count'] = { one = '{count} acción disponible', other = '{count} acciones disponibles' }
assert(i18n.t('test.count', { count = 1 }) == '1 action available')
assert(i18n.t('test.count', { count = 0 }) == '0 actions available')
assert(i18n.t('test.count', { count = 3 }) == '3 actions available')
assert(i18n.t('tasks.confirm_script', { path = '/tmp/50%/{literal}.sh' }) == 'Run script:\n/tmp/50%/{literal}.sh')
local saved = en['ai_text.copied']
en['ai_text.copied'] = nil
assert(i18n.t('ai_text.copied') == es['ai_text.copied'])
en['ai_text.copied'] = saved
assert(i18n.t('missing.key') == 'missing.key')
assert(i18n.t('ai_text.error'):find('{status}', 1, true))
i18n.setLanguage('es-AR')
assert(i18n.t('test.count', { count = 1 }) == '1 acción disponible')
assert(i18n.t('test.count', { count = 2 }) == '2 acciones disponibles')
i18n.setLanguage('unsupported')
assert(i18n.language() == 'es')
for key in pairs(i18n.catalog('task_ui.')) do
  assert(key:sub(1, 8) == 'task_ui.')
end
-- Both catalogs resolve in the action module without changing IDs or prompts.
package.loaded['modules.ai_text.actions'] = nil
local spanish = require('modules.ai_text.actions')
i18n.setLanguage('en')
package.loaded['modules.ai_text.actions'] = nil
local english = require('modules.ai_text.actions')
for index, action in ipairs(spanish.list) do
  assert(action.id == english.list[index].id and action.prompt == english.list[index].prompt)
end
assert(english.byId.translate_en.title == 'Translate to English')
print(
  'PASS: '
    .. count
    .. ' bilingual keys, parameters, plural forms, fallback, locale normalization and stable action contracts.'
)
