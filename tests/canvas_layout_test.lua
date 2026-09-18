--- Verify pure layout boundaries for small screens, empty catalogs and clamped pages.
-- @script tests.canvas_layout_test
-- Test doubles keep these assertions independent of real apps and personal settings.

local layout = require('modules.deck.canvas_layout')
local screen = { x = -1200, y = 25, w = 1200, h = 850 }
local g = layout.calculate(screen, 6, 1, 5)
assert(g.rows == 2 and g.columns == 3 and g.pages == 1 and g.y == 25)
assert(g.x == screen.x + (screen.w - g.w) / 2)
g = layout.calculate(screen, 6, 1, 2)
assert(g.pages == 2 and g.first == 1 and g.last == 4)
local second = layout.calculate(screen, 6, 2, 2)
assert(second.first == 5 and second.last == 6 and second.w == g.w and second.h == g.h)
assert(layout.calculate(screen, 6, 99, 2).page == 2)
assert(layout.calculate(screen, 1, 1, 5).rows == 1)
assert(layout.calculate(screen, 0, 1, 5).pages == 1)
g = layout.calculate({ x = 0, y = 24, w = 320, h = 600 }, 20, 1, 5)
assert(g.w <= 304 and g.rows == 2 and g.pages == 5)
local detailed = layout.calculate(screen, 7, 1, 5, true)
assert(detailed.tileHeight == 110 and detailed.tileWidth == 140 and detailed.rows == 2)
assert(detailed.w < screen.w and detailed.h < screen.h)
print('Canvas layout tests passed')
