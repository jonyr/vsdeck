--- Present the searchable native list of text actions.
-- @module modules.ai_text.chooser

local t = require('modules.i18n').t
local style = require('modules.ai_text.style')

local M = {}

-- Search display metadata without altering action IDs or model instructions.
local function buildChoices(actions, modeLabel, query)
  local choices = {}
  query = query and query:lower() or ''

  for _, action in ipairs(actions.list) do
    local haystack = table
      .concat({
        action.title,
        action.subtitle,
        action.keywords,
      }, ' ')
      :lower()

    if query == '' or haystack:find(query, 1, true) then
      table.insert(choices, {
        text = style.actionChoiceText(action),
        subText = style.actionChoiceSubText(action, modeLabel),
        actionId = action.id,
      })
    end
  end

  return choices
end

--- Build and show a chooser for one output mode.
-- @param actions Catalog with list and byId indexes.
-- @param mode "copy" or "replace".
-- @param runAction Callback receiving the selected action and output mode.
function M.show(actions, mode, runAction)
  local modeLabel = mode == 'copy' and t('text.copy') or t('text.replace')

  local chooser = hs.chooser.new(function(choice)
    if not choice then
      return
    end

    local action = actions.byId[choice.actionId]
    if action then
      runAction(action, mode)
    end
  end)

  chooser
    :placeholderText(t('text.search', { mode = modeLabel }))
    :fgColor({ red = 0.20, green = 0.20, blue = 0.20, alpha = 1 })
    :subTextColor({ red = 0.52, green = 0.52, blue = 0.52, alpha = 1 })
    :rows(#actions.list)
    :width(45)
    :choices(buildChoices(actions, modeLabel))

  chooser:queryChangedCallback(function(query)
    chooser:choices(buildChoices(actions, modeLabel, query))
  end)

  chooser:show()
end

return M
