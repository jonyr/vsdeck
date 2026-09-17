--- Derive optional editing hints from the foreground application name.
-- @module modules.ai_text.app_context

local M = {}

--- Return the foreground application name, or an empty string when unavailable.
function M.activeAppName()
  local app = hs.application.frontmostApplication()
  if app then
    return app:name() or ''
  end
  return ''
end

--- Build a context hint subordinate to the selected transformation.
-- Browser tab contents are not inspected, so websites cannot be identified here.
function M.styleInstruction()
  local app = M.activeAppName():lower()

  if app:find('mail') or app:find('gmail') or app:find('outlook') then
    return 'The source application is an email client. Do not add email structure unless the selected action requests it.'
  end

  if app:find('slack') or app:find('teams') or app:find('discord') then
    return 'The source application is a chat client. Prefer natural wording without extra shortening beyond the selected action.'
  end

  if app:find('cursor') or app:find('code') or app:find('terminal') or app:find('iterm') then
    return 'The source application is a technical editor or terminal. Preserve technical terminology accurately and leave code, commands, paths, and identifiers unchanged.'
  end

  if app:find('notes') or app:find('notion') or app:find('docs') then
    return 'The source application is a notes or document editor. Retain the existing organization unless the selected action requires a different structure.'
  end

  return 'No additional application-specific style is required.'
end

return M
