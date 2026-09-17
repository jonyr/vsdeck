local style = require('modules.ai_text.style')

local M = {}

local function buildChoices(actions, modeLabel, query)
  local choices = {}
  query = query and query:lower() or ''

  for _, action in ipairs(actions.list) do
    local haystack = table.concat({
      action.title,
      action.subtitle,
      action.keywords
    }, ' '):lower()

    if query == '' or haystack:find(query, 1, true) then
      table.insert(choices, {
        text = style.actionChoiceText(action),
        subText = style.actionChoiceSubText(action, modeLabel),
        actionId = action.id
      })
    end
  end

  return choices
end

function M.show(actions, mode, runAction)
  local modeLabel = mode == 'copy' and 'Copiar resultado' or 'Reemplazar seleccion'

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
    :placeholderText(modeLabel .. ' - busca por idioma, tono, email, chat...')
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
