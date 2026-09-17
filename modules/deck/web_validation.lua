--- Validate web shortcut input before any browser side effect occurs.
-- @module modules.deck.web_validation

local t = require('modules.i18n').t
local M = {}

-- URLs are copied before starting so callers cannot change a running sequence.
--- Reject empty profile names and control characters.
-- @return true, or nil plus an error message.
function M.profile(profile)
  if type(profile) ~= 'string' or profile:match('^%s*$') or profile:find('%c') then
    return nil, t('web.invalid_profile')
  end
  return true
end

--- Validate and copy a nonempty, consecutive HTTP(S) URL list.
-- @return Independent ordered list, or nil plus an error message.
function M.urls(urls)
  if type(urls) ~= 'table' then
    return nil, t('web.url_list')
  end
  local count = 0
  for key in pairs(urls) do
    if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then
      return nil, t('web.url_sequence')
    end
    count = count + 1
  end
  if count == 0 then
    return nil, t('web.url_empty')
  end
  local copy = {}
  for index = 1, count do
    local url = urls[index]
    if type(url) ~= 'string' or not url:match('^https?://[^/%s?#]+') or url:find('[%s%c]') then
      return nil, t('web.url_invalid')
    end
    copy[index] = url
  end
  return copy
end

-- Compatibility for callers that validate an explicit profile and URL list.
--- Validate the legacy explicit-profile call shape.
-- @return Independent URL list, or nil plus an error message.
function M.validate(profile, urls)
  local ok, err = M.profile(profile)
  if not ok then
    return nil, err
  end
  return M.urls(urls)
end

--- Normalize a shortcut against its browser-specific profile field.
-- @return Request and registry entry, or nil, nil and an error message.
function M.request(shortcut, registry)
  if type(shortcut) ~= 'table' then
    return nil, nil, t('web.config_missing')
  end
  local browser = shortcut.browser or 'safari'
  local spec = type(browser) == 'string' and registry[browser]
  if not spec then
    return nil, nil, t('web.invalid_browser')
  end
  local urls, err = M.urls(shortcut.urls)
  if not urls then
    return nil, nil, err
  end
  local other = spec.profileField == 'profile' and 'profileDirectory' or 'profile'
  if shortcut[other] ~= nil then
    return nil, nil, t('web.profile_field', { browser = spec.label, field = spec.profileField, other = other })
  end
  local profile = shortcut[spec.profileField]
  if profile ~= nil then
    local ok, profileErr = M.profile(profile)
    if not ok then
      return nil, nil, profileErr
    end
    if spec.profileField == 'profileDirectory' and (profile == '.' or profile == '..' or profile:find('[/\\]')) then
      return nil, nil, t('web.profile_directory')
    end
  end
  return { browser = browser, urls = urls, [spec.profileField] = profile }, spec
end

return M
