--- Render a paginated native Canvas interface over the shared action catalog.
-- @module modules.deck.canvas_demo

local t = require('modules.i18n').t
local sourceWindow = require('modules.deck.source_window')
-- Native Canvas interface over the shared action catalog and executor.
local M = {}
-- Retain UI and key objects across callbacks; page and output mode survive redraws.
local canvas, toggleKey, escapeKey
local page = 1
local layout = require('modules.deck.canvas_layout')
local tiles = require('modules.deck.actions').list
local executor = require('modules.deck.executor').new()
local origin
local mode = 'replace'
local colors = {
  Texto = '#85adff',
  Ventanas = '#74d9bb',
  Web = '#c5a0ff',
  Tareas = '#f1c580',
  Luces = '#ed9dbb',
  Sonidos = '#f6bd72',
}

--- Hide the Canvas and release its Escape binding.
function M.hide()
  if canvas then
    canvas:hide()
  end
  if escapeKey then
    escapeKey:disable()
  end
end

--- Rebuild the current page and capture the source window when first opening.
-- @return The retained Canvas object.
function M.show()
  if not canvas or not canvas:isShowing() then
    if executor.isBusy() then
      return
    end
    origin = sourceWindow.capture()
  end
  if canvas then
    canvas:delete()
  end
  local screen = hs.screen.mainScreen():frame()
  local options = require('modules.config.personal').data.canvasDeck or {}
  local geometry = layout.calculate(screen, #tiles, page, options.maxColumns)
  page = geometry.page
  local width, height = geometry.w, geometry.h + 24
  canvas = hs.canvas
    .new({ x = geometry.x, y = geometry.y, w = width, h = height })
    :level(hs.canvas.windowLevels.floating)
    :clickActivating(false)
  local function append(element)
    canvas:appendElements(element)
    return canvas:elementCount()
  end
  local function text(value, x, y, w, h, size, color)
    append({
      type = 'text',
      text = value,
      textSize = size,
      textFont = '.AppleSystemUIFont',
      textColor = { hex = color },
      frame = { x = x, y = y, w = w, h = h },
    })
  end
  append({
    type = 'rectangle',
    action = 'fill',
    fillColor = { hex = '#141b28' },
    roundedRectRadii = { xRadius = 20, yRadius = 20 },
    frame = { x = 0, y = 0, w = width, h = height },
  })
  text('Canvas Deck', 16, 12, width - 56, 26, 16, '#eef2fa')
  text('×', width - 38, 8, 28, 30, 24, '#a2aec2')
  append({
    type = 'rectangle',
    id = 'close',
    action = 'fill',
    fillColor = { alpha = 0 },
    frame = { x = width - 44, y = 4, w = 40, h = 40 },
    trackMouseUp = true,
    trackMouseByBounds = true,
  })
  text(t('deck.mode.' .. mode) .. ' ▾', 16, 42, width - 32, 24, 12, '#a2aec2')
  append({
    type = 'rectangle',
    id = 'mode',
    action = 'fill',
    fillColor = { alpha = 0 },
    frame = { x = 16, y = 40, w = width - 32, h = 30 },
    trackMouseUp = true,
    trackMouseByBounds = true,
  })
  -- Draw only the current page while keeping hit targets mapped to global catalog indexes.
  local tileW, tileH = geometry.tileWidth, geometry.tileHeight
  local backgrounds = {}
  for i = geometry.first, geometry.last do
    local tile = tiles[i]
    local slot = i - geometry.first
    local x = geometry.padding + (slot % geometry.columns) * (tileW + geometry.gap)
    local y = 76 + math.floor(slot / geometry.columns) * (tileH + geometry.gap)
    backgrounds[i] = append({
      type = 'rectangle',
      action = 'fill',
      fillColor = { hex = '#222e42' },
      roundedRectRadii = { xRadius = 8, yRadius = 8 },
      frame = { x = x, y = y, w = tileW, h = tileH },
    })
    text(tile.badge, x + 8, y + 7, tileW - 16, 24, 17, colors[tile.category] or '#85adff')
    text(tile.title, x + 8, y + 29, tileW - 16, 32, 10, '#eef2fa')
    -- A single hit area above text prevents hover flicker between label and background.
    append({
      type = 'rectangle',
      id = 'tile' .. i,
      action = 'fill',
      fillColor = { alpha = 0 },
      frame = { x = x, y = y, w = tileW, h = tileH },
      trackMouseByBounds = true,
      trackMouseUp = true,
      trackMouseEnterExit = true,
    })
  end
  text(t('canvas.hover'), 16, height - 28, width - 140, 22, 10, '#a2aec2')
  local status = canvas:elementCount()
  text(page .. ' / ' .. geometry.pages, width - 91, height - 29, 50, 22, 12, '#a2aec2')
  for _, nav in ipairs({
    { 'previous', '‹', width - 123, page > 1 },
    { 'next', '›', width - 40, page < geometry.pages },
  }) do
    text(nav[2], nav[3] + 8, height - 35, 24, 30, 24, nav[4] and '#eef2fa' or '#4a5364')
    if nav[4] then
      append({
        type = 'rectangle',
        id = nav[1],
        action = 'fill',
        fillColor = { alpha = 0 },
        frame = { x = nav[3], y = height - 38, w = 36, h = 36 },
        trackMouseUp = true,
        trackMouseByBounds = true,
      })
    end
  end
  -- Navigation rebuilds the panel; action dispatch still targets the captured source window.
  canvas:mouseCallback(function(_, event, id)
    if id == 'close' and event == 'mouseUp' then
      M.hide()
      return
    end
    if event == 'mouseUp' and (id == 'next' or id == 'previous') then
      page = page + (id == 'next' and 1 or -1)
      M.show()
      return
    end
    if event == 'mouseUp' and id == 'mode' then
      mode = mode == 'replace' and 'copy' or 'replace'
      M.show()
      return
    end
    local index = type(id) == 'string' and tonumber(id:match('^tile(%d+)$'))
    if not index or not tiles[index] or not backgrounds[index] then
      return
    end
    if event == 'mouseEnter' then
      canvas:elementAttribute(status, 'text', tiles[index].title)
    end
    if event == 'mouseEnter' or event == 'mouseExit' then
      canvas:elementAttribute(
        backgrounds[index],
        'fillColor',
        { hex = event == 'mouseEnter' and '#344866' or '#222e42' }
      )
    elseif event == 'mouseUp' then
      executor.run(tiles[index], origin, mode)
    end
  end)
  if not escapeKey then
    escapeKey = hs.hotkey.new({}, 'escape', M.hide)
  end
  escapeKey:enable()
  canvas:show()
  return canvas
end

--- Hide the visible panel or open it at its first page.
function M.toggle()
  if canvas and canvas:isShowing() then
    M.hide()
  else
    page = 1
    M.show()
  end
end

--- Replace this interface's global toggle binding.
function M.bindHotkeys(modifiers, key)
  if toggleKey then
    toggleKey:delete()
  end
  toggleKey = hs.hotkey.bind(modifiers, key or 'X', M.toggle)
end

--- Cancel pending dispatch and release Canvas and keyboard resources.
function M.stop()
  executor.cancel()
  M.hide()
  if canvas then
    canvas:delete()
    canvas = nil
  end
  if toggleKey then
    toggleKey:delete()
    toggleKey = nil
  end
  if escapeKey then
    escapeKey:delete()
    escapeKey = nil
  end
end

return M
