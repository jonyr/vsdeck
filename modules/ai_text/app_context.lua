local M = {}

function M.activeAppName()
  local app = hs.application.frontmostApplication()
  if app then
    return app:name() or ''
  end
  return ''
end

function M.styleInstruction()
  local app = M.activeAppName():lower()

  if app:find('mail') or app:find('gmail') or app:find('outlook') then
    return 'Format the result as a polished professional email when appropriate.'
  end

  if app:find('slack') or app:find('teams') or app:find('discord') then
    return 'Keep the result concise, direct, and suitable for a chat message.'
  end

  if app:find('cursor') or app:find('code') or app:find('terminal') or app:find('iterm') then
    return 'Preserve technical terms, code blocks, commands, Markdown, file paths, and identifiers exactly.'
  end

  if app:find('notes') or app:find('notion') or app:find('docs') then
    return 'Make the result clear, structured, and easy to read.'
  end

  return 'Use a clear, natural, professional style.'
end

return M
