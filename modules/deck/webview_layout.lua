--- Position a borderless Deck below its menu-bar item within the usable screen.
-- @module modules.deck.webview_layout

local M = {}

--- Calculate panel bounds without depending on Hammerspoon objects.
-- @param frame Usable screen rectangle, excluding the menu bar and Dock.
-- @param anchor Optional menu-bar item rectangle in screen coordinates.
-- @param options Optional settings with a nonnegative menuBarGap in points.
-- @return Rectangle constrained to the available screen area.
function M.calculate(frame, anchor, options)
  options = type(options) == 'table' and options or {}
  local gap = options.menuBarGap
  if type(gap) ~= 'number' or gap ~= gap or gap < 0 or gap == math.huge then
    gap = 6
  end

  -- Leave breathing room at screen edges and shrink on small displays.
  local edge = math.min(12, frame.w / 4, frame.h / 4)
  local w = math.min(860, frame.w - edge * 2)
  local top = math.max(frame.y, anchor and (anchor.y + anchor.h) or frame.y)
  local y = math.min(top + gap, frame.y + frame.h - edge - 1)
  local h = math.min(660, frame.y + frame.h - edge - y)
  local center = anchor and (anchor.x + anchor.w / 2) or (frame.x + frame.w / 2)
  local x = math.max(frame.x + edge, math.min(center - w / 2, frame.x + frame.w - edge - w))
  return { x = x, y = y, w = w, h = h }
end

return M
