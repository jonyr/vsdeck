--- Calculate two-row pagination without depending on Hammerspoon APIs.
-- @module modules.deck.canvas_layout

-- Pure geometry, independent of Hammerspoon and action execution.
local M = {}
--- Compute bounds and the action slice for a clamped page number.
-- @param screen Frame with x, y, w and h coordinates.
-- @param count Number of actions in the catalog.
-- @param requestedPage One-based page; defaults to 1.
-- @param maxColumns Optional column limit, constrained by available width.
-- @return Geometry table including first/last action indexes and page count.
function M.calculate(screen, count, requestedPage, maxColumns)
  local padding, gap, tileWidth, tileHeight = 16, 10, 96, 62
  maxColumns = tonumber(maxColumns) or 5
  maxColumns = math.max(1, math.floor(maxColumns))
  local availableColumns = math.max(1, math.floor((screen.w - 16 - padding * 2 + gap) / (tileWidth + gap)))
  local columns = math.min(maxColumns, availableColumns, math.max(1, math.ceil(count / 2)))
  -- Keep empty catalogs and out-of-range page requests valid without adding a third row.
  local capacity = columns * 2
  local pages = math.max(1, math.ceil(count / capacity))
  local page = math.max(1, math.min(requestedPage or 1, pages))
  local rows = math.min(2, math.max(1, math.ceil(count / columns)))
  local width = math.max(260, padding * 2 + columns * tileWidth + (columns - 1) * gap)
  local height = 52 + rows * tileHeight + (rows - 1) * gap + 40
  return {
    x = screen.x + (screen.w - width) / 2,
    y = screen.y,
    w = width,
    h = height,
    columns = columns,
    rows = rows,
    capacity = capacity,
    pages = pages,
    page = page,
    first = (page - 1) * capacity + 1,
    last = math.min(count, page * capacity),
    tileWidth = tileWidth,
    tileHeight = tileHeight,
    padding = padding,
    gap = gap,
  }
end
return M
