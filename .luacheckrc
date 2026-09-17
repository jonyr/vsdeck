-- Hammerspoon embeds Lua 5.4 and provides the hs global at runtime.
std = 'lua54'
read_globals = { 'hs' }

-- StyLua owns layout; long prompts and translation strings should stay intact.
max_line_length = false

-- Test doubles intentionally replace hs and accept unused callback arguments.
files['tests/**/*.lua'] = {
  globals = { 'hs' },
  unused_args = false,
}
