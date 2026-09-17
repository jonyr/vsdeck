--- Render chooser labels with action-specific badge colors.
-- @module modules.ai_text.style

local styledtext = hs.styledtext

-- Keep badge colors keyed by stable action IDs, independent of display language.
local actionColors = {
  translate_en = { red = 0.12, green = 0.46, blue = 0.92, alpha = 1 },
  fix_same_language = { red = 0.10, green = 0.56, blue = 0.36, alpha = 1 },
  translate_es = { red = 0.88, green = 0.33, blue = 0.22, alpha = 1 },
  professional = { red = 0.48, green = 0.34, blue = 0.86, alpha = 1 },
  shorten = { red = 0.86, green = 0.53, blue = 0.16, alpha = 1 },
  email = { red = 0.14, green = 0.55, blue = 0.68, alpha = 1 },
  chat = { red = 0.16, green = 0.58, blue = 0.24, alpha = 1 },
  auto = { red = 0.42, green = 0.45, blue = 0.50, alpha = 1 },
}

local M = {}

--- Build a styled badge and title for a chooser row.
function M.actionChoiceText(action)
  local color = actionColors[action.id] or { red = 0.18, green = 0.18, blue = 0.18, alpha = 1 }
  local badge = string.format('%-4s', action.badge)
  local title = badge .. '  ' .. action.title

  return styledtext
    .new(title, {
      font = { name = '.AppleSystemUIFont', size = 16 },
      color = { red = 0.28, green = 0.28, blue = 0.28, alpha = 1 },
    })
    :setStyle({
      font = { name = '.AppleSystemUIFontBold', size = 15 },
      color = color,
    }, 1, #badge)
end

--- Build the secondary row containing output mode and action description.
function M.actionChoiceSubText(action, modeLabel)
  local text = modeLabel .. ' - ' .. action.subtitle

  return styledtext.new(text, {
    font = { name = '.AppleSystemUIFont', size = 12 },
    color = { red = 0.54, green = 0.54, blue = 0.54, alpha = 1 },
  })
end

return M
