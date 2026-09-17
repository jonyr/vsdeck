--- Resolve localized UI strings with named parameters and Spanish fallback.
-- @module modules.i18n.init

-- Catalogs are trusted project modules. Locale changes take effect after reload.
local catalogs = { es = require('modules.i18n.locales.es'), en = require('modules.i18n.locales.en') }
local M = {}
-- Deduplicate diagnostics to avoid flooding the Hammerspoon console during redraws.
local warned = {}
local requested = require('modules.config.personal').data.language or 'es'
local function warn(message)
  if not warned[message] then
    print('[i18n] ' .. message)
    warned[message] = true
  end
end
local function locale(value)
  local language = type(value) == 'string' and value:lower():match('^[a-z]+') or 'es'
  if not catalogs[language] then
    warn('Unsupported language: ' .. tostring(value))
    return 'es'
  end
  return language
end
local language = locale(requested)
--- Return the normalized active language code.
function M.language()
  return language
end

--- Select a supported language, falling back to Spanish.
-- Existing action titles are computed at load time; normal changes require reload.
function M.setLanguage(value)
  language = locale(value)
end
-- Fallback resolves missing keys in Spanish before exposing the key as a diagnostic.
local function lookup(key)
  local value = catalogs[language][key]
  if value == nil then
    warn('Missing translation: ' .. language .. ':' .. key)
    value = catalogs.es[key]
  end
  return value
end

--- Resolve a message and substitute named parameters literally.
-- @param key Stable catalog key.
-- @param params Optional values; numeric count selects one/other plural forms.
-- @return Localized text, Spanish fallback, or the key when missing in both.
function M.t(key, params)
  params = params or {}
  local value = lookup(key)
  if type(value) == 'table' then
    -- English and Spanish both use one for exactly 1, other otherwise.
    value = value[params.count == 1 and 'one' or 'other']
  end
  if type(value) ~= 'string' then
    warn('Missing key: ' .. key)
    return key
  end
  return (
    value:gsub('{([%w_]+)}', function(name)
      if params[name] == nil then
        warn('Missing parameter: ' .. key .. ':' .. name)
        return '{' .. name .. '}'
      end
      return tostring(params[name])
    end)
  )
end
-- Public UI strings only; used by the webview. No configuration crosses this boundary.
--- Export public message entries for a UI namespace.
-- @param prefix Optional key prefix such as "deck.".
-- @return Map of messages; plural entries retain their one/other variants.
function M.catalog(prefix)
  local result = {}
  for key in pairs(catalogs.es) do
    if not prefix or key:sub(1, #prefix) == prefix then
      result[key] = lookup(key)
    end
  end
  return result
end
return M
