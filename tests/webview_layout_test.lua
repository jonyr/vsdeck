--- Verify menu anchoring and usable bounds independently of native windows.
-- @script tests.webview_layout_test

local layout = require('modules.deck.webview_layout')
local frame = { x = 0, y = 24, w = 1440, h = 816 }
local function within(rect, screen)
  assert(rect.w > 0 and rect.h > 0)
  assert(rect.x >= screen.x and rect.y >= screen.y)
  assert(rect.x + rect.w <= screen.x + screen.w)
  assert(rect.y + rect.h <= screen.y + screen.h)
end
local anchor = { x = 700, y = 0, w = 24, h = 24 }
local rect = layout.calculate(frame, anchor)
assert(rect.x == 282 and rect.y == 30 and rect.w == 860 and rect.h == 660)
assert(layout.calculate(frame, anchor, { menuBarGap = 0 }).y == 24)
assert(layout.calculate(frame, anchor, { menuBarGap = 18 }).y == 42)
-- Edge icons and secondary displays with negative coordinates stay on their screen.
for _, x in ipairs({ 0, 1416 }) do
  within(layout.calculate(frame, { x = x, y = 0, w = 24, h = 24 }), frame)
end
local secondary = { x = -1920, y = -1000, w = 1920, h = 950 }
rect = layout.calculate(secondary, { x = -100, y = -1024, w = 24, h = 24 })
within(rect, secondary)
assert(rect.y == -994)
local small = { x = 0, y = 38, w = 400, h = 300 }
rect = layout.calculate(small, { x = 376, y = 0, w = 24, h = 38 })
within(rect, small)
assert(rect.w == 376 and rect.h == 282)
-- Missing icons fall back to the top center; malformed preferences use defaults.
rect = layout.calculate(frame, nil)
assert(rect.x == 290 and rect.y == 30)
for _, options in ipairs({ false, 'bad', { menuBarGap = -1 }, { menuBarGap = math.huge }, { menuBarGap = 0 / 0 } }) do
  assert(layout.calculate(frame, anchor, options).y == 30)
end
within(layout.calculate(frame, anchor, { menuBarGap = 100000 }), frame)
print('PASS: menu anchoring, gap settings, screen edges, secondary displays, small screens and fallback.')
