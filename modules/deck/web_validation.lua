local M = {}

-- URLs are copied before starting so callers cannot change a running sequence.
function M.profile(profile)
  if type(profile) ~= 'string' or profile:match('^%s*$') or profile:find('%c') then
    return nil, 'Indica un nombre de perfil válido.'
  end
  return true
end

function M.urls(urls)
  if type(urls) ~= 'table' then return nil, 'Indica una lista de URLs.' end
  local count = 0
  for key in pairs(urls) do
    if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then
      return nil, 'Las URLs deben formar una lista consecutiva.'
    end
    count = count + 1
  end
  if count == 0 then return nil, 'Agrega al menos una URL.' end
  local copy = {}
  for index = 1, count do
    local url = urls[index]
    if type(url) ~= 'string' or not url:match('^https?://[^/%s?#]+') or url:find('[%s%c]') then
      return nil, 'Cada URL debe comenzar con http:// o https:// y no contener espacios.'
    end
    copy[index] = url
  end
  return copy
end

-- Compatibility for callers that validate an explicit profile and URL list.
function M.validate(profile, urls)
  local ok, err = M.profile(profile)
  if not ok then return nil, err end
  return M.urls(urls)
end

function M.request(shortcut, registry)
  if type(shortcut) ~= 'table' then return nil, nil, 'Indica la configuración del acceso web.' end
  local browser = shortcut.browser or 'safari'
  local spec = type(browser) == 'string' and registry[browser]
  if not spec then return nil, nil, 'Navegador no válido. Revisa el registro de navegadores.' end
  local urls, err = M.urls(shortcut.urls)
  if not urls then return nil, nil, err end
  local other = spec.profileField == 'profile' and 'profileDirectory' or 'profile'
  if shortcut[other] ~= nil then
    return nil, nil, spec.label .. ' usa ' .. spec.profileField .. ', no ' .. other .. '.'
  end
  local profile = shortcut[spec.profileField]
  if profile ~= nil then
    local ok, profileErr = M.profile(profile)
    if not ok then return nil, nil, profileErr end
    if spec.profileField == 'profileDirectory' and
        (profile == '.' or profile == '..' or profile:find('[/\\]')) then
      return nil, nil, 'profileDirectory debe ser el nombre de una carpeta, no una ruta.'
    end
  end
  return { browser = browser, urls = urls, [spec.profileField] = profile }, spec
end

return M
